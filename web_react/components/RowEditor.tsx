"use client";

import { useMemo } from "react";
import { CsvRow, HeaderMeta, computeRowWorkHours } from "@/lib/csv";

interface RowEditorProps {
  row: CsvRow | null;
  headerMeta: HeaderMeta[];
  onChange: (row: CsvRow) => void;
}

const CORE_WIDGETS = new Set([
  "date",
  "startofwork",
  "endofwork",
  "breaktime",
  "workhours",
  "wellbeing",
  "diaryentry",
]);

export function RowEditor({ row, headerMeta, onChange }: RowEditorProps) {
  if (!row) {
    return (
      <div className="panel">
        <p>No row selected yet.</p>
      </div>
    );
  }

  if (row.date === "SUMMARY") {
    return (
      <div className="panel">
        <div className="date-widget">
          <div className="date-title">Monthly Summary</div>
          <div className="date-caption">
            This row summarizes the full month and is not editable here.
          </div>
        </div>
      </div>
    );
  }

  const update = (key: string, value: string) => {
    onChange({ ...row, [key]: value });
  };

  const derivedWorkHours = computeRowWorkHours(row);
  const hasStartEnd = Boolean(row.startofwork) && Boolean(row.endofwork);

  const grouped = useMemo(() => {
    const map = new Map<string, HeaderMeta[]>();
    headerMeta.forEach((item) => {
      if (item.key === "date") return;
      const topic = item.topic || "General";
      if (!map.has(topic)) map.set(topic, []);
      map.get(topic)!.push(item);
    });
    return Array.from(map.entries()).filter(([, items]) => items.length > 0);
  }, [headerMeta]);

  return (
    <div className="panel">
      <div className="date-widget">
        <div className="date-title">Row Date</div>
        <input id="date" type="text" value={row.date ?? ""} readOnly />
        <div className="date-caption">This date defines which row is selected.</div>
      </div>
      {grouped.map(([topic, items]) => (
        <div key={topic} className="list-group">
          <div className="list-topic">{topic}</div>
          <div className="list-items">
            {items.map((item) => {
              const key = item.key;
              const label = item.subtopic || item.raw || key;

              if (key === "date") {
                return null;
              }

              if (key === "diaryentry") {
                return (
                  <div key={key} className="list-item long">
                    <label htmlFor={key}>{label}</label>
                    <textarea
                      id={key}
                      value={row[key] ?? ""}
                      onChange={(event) => update(key, event.target.value)}
                    />
                  </div>
                );
              }

              if (key === "wellbeing") {
                return (
                  <div key={key} className="list-item">
                    <label htmlFor={key}>{label}</label>
                    <div>
                      <input
                        id={key}
                        type="range"
                        className="slider"
                        min={1}
                        max={10}
                        value={row[key] || "5"}
                        onChange={(event) => update(key, event.target.value)}
                      />
                      <div className="pill">{row[key] || "5"}/10</div>
                    </div>
                  </div>
                );
              }

              if (key === "startofwork" || key === "endofwork") {
                return (
                  <div key={key} className="list-item">
                    <label htmlFor={key}>{label}</label>
                    <input
                      id={key}
                      type="time"
                      value={row[key] ?? ""}
                      onChange={(event) => update(key, event.target.value)}
                    />
                  </div>
                );
              }

              if (key === "breaktime") {
                return (
                  <div key={key} className="list-item">
                    <label htmlFor={key}>{label}</label>
                    <input
                      id={key}
                      type="text"
                      placeholder="e.g. 30 or 00:30"
                      value={row[key] ?? ""}
                      onChange={(event) => update(key, event.target.value)}
                    />
                  </div>
                );
              }

              if (key === "workhours") {
                const value =
                  hasStartEnd && derivedWorkHours !== null
                    ? derivedWorkHours.toString()
                    : row[key] ?? "";
                return (
                  <div key={key} className="list-item">
                    <label htmlFor={key}>{label}</label>
                    <input
                      id={key}
                      type="text"
                      value={value}
                      readOnly={hasStartEnd}
                      onChange={(event) => update(key, event.target.value)}
                    />
                  </div>
                );
              }

              if (!CORE_WIDGETS.has(key)) {
                return (
                  <div key={key} className="list-item">
                    <label htmlFor={key}>{label}</label>
                    <input
                      id={key}
                      type="text"
                      value={row[key] ?? ""}
                      onChange={(event) => update(key, event.target.value)}
                    />
                  </div>
                );
              }

              return null;
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
