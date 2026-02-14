"use client";

import { useMemo, useState } from "react";
import Papa from "papaparse";
import {
  CsvRow,
  DateFormatKey,
  DEFAULT_COLUMNS,
  HeaderMeta,
  buildHeaderRowsFromMeta,
  buildHeaderMeta,
  computeRowWorkHours,
  computeTotalWorkHours,
  computeAverageWellbeing,
  detectDateFormat,
  findTodayRow,
  formatDateForCsv,
  generateMonthlyCsv,
  hydrateRows,
  parseHeaderRows,
} from "@/lib/csv";
import { RowEditor } from "@/components/RowEditor";
import { DateFormatConfirm } from "@/components/DateFormatConfirm";

const today = new Date();

export default function Home() {
  const [csvText, setCsvText] = useState("");
  const [headerMeta, setHeaderMeta] = useState<HeaderMeta[]>([]);
  const [rows, setRows] = useState<CsvRow[]>([]);
  const [headerStyle, setHeaderStyle] = useState<"single" | "topic">("topic");
  const [dateFormat, setDateFormat] = useState<DateFormatKey | "">("");
  const [dateCandidates, setDateCandidates] = useState<DateFormatKey[]>([]);
  const [selectedRowIndex, setSelectedRowIndex] = useState<number | null>(null);
  const [customColumns, setCustomColumns] = useState<string[]>([]);
  const [month, setMonth] = useState(() => today.getMonth());
  const [year, setYear] = useState(() => today.getFullYear());
  const [status, setStatus] = useState("Ready");

  const allColumns = useMemo(() => {
    return headerMeta.length ? headerMeta.map((item) => item.key) : DEFAULT_COLUMNS;
  }, [headerMeta]);

  const previewRows = useMemo(() => {
    if (!rows.length) return [];
    return rows.slice(0, 8);
  }, [rows]);

  const topicGroups = useMemo(() => {
    if (headerStyle === "single") return [];
    const groups: { topic: string; span: number }[] = [];
    headerMeta.forEach((item) => {
      const topic = item.topic || "General";
      const last = groups[groups.length - 1];
      if (!last || last.topic !== topic) {
        groups.push({ topic, span: 1 });
      } else {
        last.span += 1;
      }
    });
    return groups;
  }, [headerMeta, headerStyle]);

  const selectedRow = selectedRowIndex !== null ? rows[selectedRowIndex] : null;

  const totalWorkHours = useMemo(() => {
    if (!rows.length) return 0;
    return computeTotalWorkHours(rows);
  }, [rows]);

  const averageWellbeing = useMemo(() => {
    if (!rows.length) return 0;
    return computeAverageWellbeing(rows);
  }, [rows]);

  const handleCsvText = (text: string) => {
    setCsvText(text);
    const parsed = Papa.parse<string[]>(text.trim(), {
      skipEmptyLines: true,
    });
    if (parsed.errors.length) {
      setStatus("CSV parse error: " + parsed.errors[0].message);
      return;
    }
    const rawData = parsed.data;
    if (!rawData.length) {
      setStatus("Empty CSV. Use Create Monthly Table.");
      return;
    }
    const parsedHeaders = parseHeaderRows(rawData);
    const meta = parsedHeaders.meta;
    const keys = meta.map((item) => item.key);
    const body = rawData.slice(parsedHeaders.dataStartIndex);
    const hydrated = hydrateRows(keys, body);
    setHeaderMeta(meta);
    setHeaderStyle(parsedHeaders.headerRows.length === 2 ? "topic" : "single");
    setRows(hydrated);
    const detection = detectDateFormat(
      hydrated.map((row) => row.date).filter((value) => Boolean(value)),
    );
    setDateCandidates(detection.candidates);
    const format = detection.format ?? "";
    setDateFormat(format);
    if (format) {
      const index = findTodayRow(hydrated, format, today);
      setSelectedRowIndex(index ?? 0);
    }
    setStatus("CSV loaded.");
  };

  const handleFileUpload = (file: File) => {
    const reader = new FileReader();
    reader.onload = () => {
      handleCsvText(reader.result as string);
    };
    reader.readAsText(file);
  };

  const mergeCustomMetaByTopic = (base: HeaderMeta[], custom: HeaderMeta[]) => {
    const result = [...base];
    custom.forEach((item) => {
      const topic = item.topic || "General";
      let insertAt = -1;
      for (let index = result.length - 1; index >= 0; index -= 1) {
        if ((result[index].topic || "General") === topic) {
          insertAt = index + 1;
          break;
        }
      }
      if (insertAt === -1) {
        result.push(item);
      } else {
        result.splice(insertAt, 0, item);
      }
    });
    return result;
  };

  const createMonthlyTable = () => {
    const coreColumns =
      headerStyle === "topic"
        ? [
            "Date::Date",
            "Work::Start",
            "Work::End",
            "Work::Break",
            "Work::Workhours",
            "Mood::Wellbeing",
            "Notes::Diary entry",
          ]
        : ["Date", "Start of work", "End of work", "Break time", "Work hours", "Wellbeing", "Diary entry"];

    const custom = customColumns
      .map((col) => col.trim())
      .filter(Boolean);
    const baseMeta = buildHeaderMeta(coreColumns);
    const customMeta = buildHeaderMeta(custom);
    const mergedMeta = headerStyle === "topic"
      ? mergeCustomMetaByTopic(baseMeta, customMeta)
      : [...baseMeta, ...customMeta];
    const meta = mergedMeta;
    const columns = meta.map((item) => item.key);
    const format = (dateFormat || "YYYY-MM-DD") as DateFormatKey;
    const generated = generateMonthlyCsv(year, month, columns, format);
    setHeaderMeta(meta);
    setRows(generated);
    setDateFormat(format);
    setCsvText("");
    setStatus("Generated new monthly table.");
    const todayIndex = findTodayRow(generated, format, today);
    setSelectedRowIndex(todayIndex ?? 0);
  };

  const onRowChange = (row: CsvRow) => {
    if (selectedRowIndex === null) return;
    const next = [...rows];
    next[selectedRowIndex] = row;
    setRows(next);
  };

  const selectTodayRow = () => {
    if (!rows.length || !dateFormat) return;
    const index = findTodayRow(rows, dateFormat as DateFormatKey, today);
    setSelectedRowIndex(index ?? 0);
  };

  const updateSummaryRow = () => {
    if (!rows.length) return;
    const summaryIndex = rows.findIndex((row) => row.date === "SUMMARY");
    if (summaryIndex === -1) return;
    const next = [...rows];
    next[summaryIndex] = {
      ...next[summaryIndex],
      workhours: totalWorkHours.toString(),
      wellbeing: averageWellbeing.toString(),
    };
    setRows(next);
  };

  const normalizeRowsForExport = () => {
    if (!rows.length) return rows;
    const next = rows.map((row) => {
      if (row.date === "SUMMARY") return row;
      const hours = computeRowWorkHours(row);
      if (hours === null) return row;
      return { ...row, workhours: hours.toString() };
    });
    return next;
  };

  const downloadCsv = () => {
    const keys = headerMeta.length ? headerMeta.map((item) => item.key) : allColumns;
    if (!keys.length || !rows.length) return;
    const headerRows = buildHeaderRowsFromMeta(
      headerMeta.length ? headerMeta : buildHeaderMeta(DEFAULT_COLUMNS),
      headerStyle,
      dateFormat || undefined,
    );
    const data = [
      ...headerRows,
      ...normalizeRowsForExport().map((row) => keys.map((h) => row[h] ?? "")),
    ];
    const csv = Papa.unparse(data);
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `valrow-${formatDateForCsv(today, (dateFormat || "YYYY-MM-DD") as DateFormatKey)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };

  return (
    <main>
      <section className="container hero">
        <div className="kicker">CSVrow</div>
        <h1>Read, edit, and save today's CSV row without touching the sheet.</h1>
        <p>
          Designed for monthly work logs. CSVrow auto-detects your date format, builds
          a full month table if missing, and gives you smart widgets for each field.
        </p>
      </section>

      <section className="container grid grid-2">
        <div className="panel">
          <div className="kicker">Data source</div>
          <p>Upload a CSV file, paste CSV text, or connect later to Google Drive.</p>
          <input
            type="file"
            accept=".csv"
            onChange={(event) => {
              const file = event.target.files?.[0];
              if (file) handleFileUpload(file);
            }}
          />
          <div style={{ marginTop: 16 }}>
            <label htmlFor="csvText">Paste CSV</label>
            <textarea
              id="csvText"
              placeholder="Paste CSV content here"
              value={csvText}
              onChange={(event) => setCsvText(event.target.value)}
            />
            <div className="actions-row">
              <button onClick={() => handleCsvText(csvText)}>Load CSV</button>
              <button className="secondary" onClick={selectTodayRow}>
                Jump to Today
              </button>
            </div>
          </div>
          <div style={{ marginTop: 18 }} className="pill">Status: {status}</div>
        </div>

        <div className="panel">
          <div className="kicker">Create monthly table</div>
          <p>Generate a new month if no CSV exists yet.</p>
          <div className="grid grid-2">
            <div>
              <label htmlFor="month">Month</label>
              <select
                id="month"
                value={month}
                onChange={(event) => setMonth(Number(event.target.value))}
              >
                {Array.from({ length: 12 }).map((_, index) => (
                  <option key={index} value={index}>
                    {new Date(2020, index, 1).toLocaleString("en-US", {
                      month: "long",
                    })}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label htmlFor="year">Year</label>
              <input
                id="year"
                type="number"
                value={year}
                onChange={(event) => setYear(Number(event.target.value))}
              />
            </div>
          </div>
          <div style={{ marginTop: 12 }}>
            <label htmlFor="custom">Custom columns</label>
            <input
              id="custom"
              type="text"
              placeholder="e.g. Work::Focus, Mood::Energy, Location"
              onChange={(event) =>
                setCustomColumns(event.target.value.split(",").map((c) => c.trim()))
              }
            />
          </div>
          <div style={{ marginTop: 12 }}>
            <label htmlFor="headerStyle">Header style</label>
            <select
              id="headerStyle"
              value={headerStyle}
              onChange={(event) => setHeaderStyle(event.target.value as "single" | "topic")}
            >
              <option value="topic">Topic + Subtopic</option>
              <option value="single">Single row</option>
            </select>
          </div>
          <div style={{ marginTop: 12 }}>
            <label htmlFor="format">Preferred date format</label>
            <select
              id="format"
              value={dateFormat}
              onChange={(event) => setDateFormat(event.target.value as DateFormatKey)}
            >
              <option value="">Auto-detect / default</option>
              <option value="YYYY-MM-DD">YYYY-MM-DD</option>
              <option value="DD/MM/YYYY">DD/MM/YYYY</option>
              <option value="MM/DD/YYYY">MM/DD/YYYY</option>
              <option value="YYYY/MM/DD">YYYY/MM/DD</option>
              <option value="DD.MM.YYYY">DD.MM.YYYY</option>
            </select>
          </div>
          <div style={{ marginTop: 14 }}>
            <button onClick={createMonthlyTable}>Create Month</button>
          </div>
        </div>
      </section>

      <section className="container" style={{ marginTop: 28 }}>
          <div className="split">
            <div className="grid" style={{ gap: 20 }}>
              {dateCandidates.length > 1 || !dateFormat ? (
                <DateFormatConfirm
                  detected={dateFormat ? (dateFormat as DateFormatKey) : null}
                  candidates={dateCandidates}
                  selected={dateFormat}
                  onSelect={(format) => setDateFormat(format)}
                />
              ) : null}
            <RowEditor row={selectedRow} headerMeta={headerMeta.length ? headerMeta : buildHeaderMeta(DEFAULT_COLUMNS)} onChange={onRowChange} />
            </div>

          <div className="panel">
            <div className="kicker">Today</div>
            <p>
              {dateFormat
                ? `Today is ${formatDateForCsv(today, dateFormat as DateFormatKey)}.`
                : "Select a date format to align with today."}
            </p>
            <div className="grid" style={{ gap: 12 }}>
              <button onClick={selectTodayRow}>Show today row</button>
              <button className="secondary" onClick={updateSummaryRow}>
                Update summary
              </button>
              <button className="secondary" onClick={downloadCsv}>
                Download CSV
              </button>
            </div>
            <div style={{ marginTop: 16 }} className="card">
              <div className="kicker">Summary</div>
              <p>Total work hours: {totalWorkHours}</p>
              <p>Average wellbeing: {averageWellbeing}</p>
            </div>
            <div style={{ marginTop: 16 }} className="card">
              <div className="kicker">CSV Preview</div>
              {headerMeta.length ? (
                <div className="csv-preview">
                  <table>
                    <thead>
                      {headerStyle === "topic" ? (
                        <tr>
                          {topicGroups.map((group, index) => (
                            <th key={`${group.topic}-${index}`} colSpan={group.span}>
                              {group.topic}
                            </th>
                          ))}
                        </tr>
                      ) : null}
                      <tr>
                        {headerMeta.map((item) => {
                          const label =
                            item.key === "date" && dateFormat
                              ? dateFormat
                              : item.subtopic || item.raw;
                          return <th key={item.key}>{label}</th>;
                        })}
                      </tr>
                    </thead>
                    <tbody>
                      {previewRows.map((row, rowIndex) => (
                        <tr key={rowIndex}>
                          {headerMeta.map((item) => (
                            <td key={`${rowIndex}-${item.key}`}>
                              {row[item.key] ?? ""}
                            </td>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <p>Load a CSV to see the merged headers.</p>
              )}
            </div>
          </div>
        </div>
      </section>

      <footer className="container footer">
        Next: Google Drive connector, URL loading, and auth.
      </footer>
    </main>
  );
}
