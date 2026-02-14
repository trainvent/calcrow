import { eachDayOfInterval, endOfMonth, format, parse, startOfMonth } from "date-fns";

export type DateFormatKey =
  | "YYYY-MM-DD"
  | "DD/MM/YYYY"
  | "MM/DD/YYYY"
  | "YYYY/MM/DD"
  | "DD.MM.YYYY";

const FORMAT_MAP: Record<DateFormatKey, string> = {
  "YYYY-MM-DD": "yyyy-MM-dd",
  "DD/MM/YYYY": "dd/MM/yyyy",
  "MM/DD/YYYY": "MM/dd/yyyy",
  "YYYY/MM/DD": "yyyy/MM/dd",
  "DD.MM.YYYY": "dd.MM.yyyy",
};

export const DEFAULT_COLUMNS = [
  "date",
  "startofwork",
  "endofwork",
  "breaktime",
  "workhours",
  "wellbeing",
  "diaryentry",
];

export type CsvRow = Record<string, string>;

export interface HeaderMeta {
  key: string;
  raw: string;
  topic: string;
  subtopic: string;
}

export interface HeaderParseResult {
  meta: HeaderMeta[];
  dataStartIndex: number;
  headerRows: string[][];
}

export interface DateFormatDetection {
  format: DateFormatKey | null;
  candidates: DateFormatKey[];
}

function isValidDate(date: Date): boolean {
  return !Number.isNaN(date.getTime());
}

export function detectDateFormat(samples: string[]): DateFormatDetection {
  const candidates: { key: DateFormatKey; score: number }[] = [];

  (Object.keys(FORMAT_MAP) as DateFormatKey[]).forEach((key) => {
    let score = 0;
    samples.forEach((value) => {
      if (!value) return;
      const parsed = parse(value, FORMAT_MAP[key], new Date());
      if (isValidDate(parsed)) {
        score += 1;
      }
    });
    if (score > 0) {
      candidates.push({ key, score });
    }
  });

  candidates.sort((a, b) => b.score - a.score);

  return {
    format: candidates.length === 1 ? candidates[0].key : null,
    candidates: candidates.map((item) => item.key),
  };
}

export function formatDateForCsv(date: Date, formatKey: DateFormatKey): string {
  return format(date, FORMAT_MAP[formatKey]);
}

export function parseCsvDate(value: string, formatKey: DateFormatKey): Date | null {
  const parsed = parse(value, FORMAT_MAP[formatKey], new Date());
  return isValidDate(parsed) ? parsed : null;
}

export function generateMonthlyCsv(
  year: number,
  monthIndex: number,
  columns: string[],
  dateFormat: DateFormatKey,
): CsvRow[] {
  const start = startOfMonth(new Date(year, monthIndex, 1));
  const end = endOfMonth(start);
  const days = eachDayOfInterval({ start, end });

  const rows = days.map((day) => {
    const row: CsvRow = {};
    columns.forEach((column) => {
      row[column] = "";
    });
    row.date = formatDateForCsv(day, dateFormat);
    return row;
  });

  const summaryRow: CsvRow = {};
  columns.forEach((column) => {
    summaryRow[column] = "";
  });
  summaryRow.date = "SUMMARY";

  return [...rows, summaryRow];
}


function parseTimeToMinutes(value: string): number | null {
  if (!value) return null;
  const trimmed = value.trim();
  if (/^\d+$/.test(trimmed)) {
    return Number.parseInt(trimmed, 10);
  }
  const match = trimmed.match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return null;
  const hours = Number.parseInt(match[1], 10);
  const minutes = Number.parseInt(match[2], 10);
  return hours * 60 + minutes;
}

function parseClockMinutes(value: string): number | null {
  const match = value.trim().match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return null;
  const hours = Number.parseInt(match[1], 10);
  const minutes = Number.parseInt(match[2], 10);
  return hours * 60 + minutes;
}

export function computeTotalWorkHours(rows: CsvRow[]): number {
  let totalMinutes = 0;

  rows.forEach((row) => {
    if (row.date === "SUMMARY") return;
    const start = row.startofwork ? parseClockMinutes(row.startofwork) : null;
    const end = row.endofwork ? parseClockMinutes(row.endofwork) : null;
    if (start === null || end === null) return;
    let minutes = end - start;
    if (minutes < 0) {
      minutes += 24 * 60;
    }
    const breakMinutes = row.breaktime ? parseTimeToMinutes(row.breaktime) : 0;
    minutes -= breakMinutes ?? 0;
    if (minutes > 0) {
      totalMinutes += minutes;
    }
  });

  return Math.round((totalMinutes / 60) * 100) / 100;
}

export function computeAverageWellbeing(rows: CsvRow[]): number {
  let total = 0;
  let count = 0;

  rows.forEach((row) => {
    if (row.date === "SUMMARY") return;
    const value = row.wellbeing ? Number.parseFloat(row.wellbeing) : NaN;
    if (Number.isNaN(value)) return;
    total += value;
    count += 1;
  });

  if (!count) return 0;
  return Math.round((total / count) * 100) / 100;
}

export function computeRowWorkHours(row: CsvRow): number | null {
  if (row.date === "SUMMARY") return null;
  const start = row.startofwork ? parseClockMinutes(row.startofwork) : null;
  const end = row.endofwork ? parseClockMinutes(row.endofwork) : null;
  if (start === null || end === null) return null;
  let minutes = end - start;
  if (minutes < 0) minutes += 24 * 60;
  const breakMinutes = row.breaktime ? parseTimeToMinutes(row.breaktime) : 0;
  minutes -= breakMinutes ?? 0;
  if (minutes <= 0) return 0;
  return Math.round((minutes / 60) * 100) / 100;
}

export function findTodayRow(
  rows: CsvRow[],
  dateFormat: DateFormatKey,
  today: Date,
): number | null {
  const target = formatDateForCsv(today, dateFormat);
  const index = rows.findIndex((row) => row.date === target);
  return index === -1 ? null : index;
}

export function normalizeHeaders(headers: string[]): string[] {
  return headers.map((header) => canonicalizeKeySimple(header));
}

export function hydrateRows(
  headers: string[],
  data: string[][],
): CsvRow[] {
  return data.map((row) => {
    const record: CsvRow = {};
    headers.forEach((header, index) => {
      record[header] = row[index] ?? "";
    });
    return record;
  });
}

function canonicalizeKeySimple(raw: string): string {
  const cleaned = raw.toLowerCase().replace(/[^a-z0-9]/g, "");
  if (cleaned === "date") return "date";
  if (["startofwork", "workstart", "startwork", "start"].includes(cleaned)) return "startofwork";
  if (["endofwork", "workend", "endwork", "end"].includes(cleaned)) return "endofwork";
  if (cleaned === "break" || cleaned === "breaktime" || cleaned === "pause") return "breaktime";
  if (cleaned === "workhours" || cleaned === "hoursworked" || cleaned === "totalhours") return "workhours";
  if (cleaned === "wellbeing" || cleaned === "mood") return "wellbeing";
  if (cleaned === "diary" || cleaned === "journal" || cleaned === "diaryentry") return "diaryentry";
  return cleaned || "col";
}

function canonicalizeKeyWithContext(raw: string, topic: string, subtopic: string): string {
  const topicKey = topic.toLowerCase().replace(/[^a-z0-9]/g, "");
  const subKey = subtopic.toLowerCase().replace(/[^a-z0-9]/g, "");

  if (subKey === "date" || topicKey === "date") return "date";
  if (topicKey === "work" && (subKey === "start" || subKey === "startofwork")) return "startofwork";
  if (topicKey === "work" && (subKey === "end" || subKey === "endofwork")) return "endofwork";
  if (topicKey === "work" && (subKey === "break" || subKey === "breaktime")) return "breaktime";
  if (topicKey === "work" && (subKey === "workhours" || subKey === "hours" || subKey === "hoursworked")) return "workhours";
  if (topicKey === "mood" && (subKey === "wellbeing" || subKey === "mood")) return "wellbeing";
  if (topicKey === "notes" && (subKey === "diary" || subKey === "diaryentry" || subKey === "journal")) return "diaryentry";

  return subKey || canonicalizeKeySimple(raw);
}

function parseHeaderLabel(raw: string): { topic: string; subtopic: string } {
  const separators = ["::", ">", ":", "|", "/"];
  for (const sep of separators) {
    if (raw.includes(sep)) {
      const [topicRaw, subRaw] = raw.split(sep);
      return {
        topic: topicRaw.trim() || raw.trim(),
        subtopic: subRaw.trim(),
      };
    }
  }
  return { topic: raw.trim(), subtopic: "" };
}

export function buildHeaderMeta(rawHeaders: string[]): HeaderMeta[] {
  const used = new Map<string, number>();
  return rawHeaders.map((raw) => {
    const { topic, subtopic } = parseHeaderLabel(raw);
    const baseKey = canonicalizeKeyWithContext(raw, topic, subtopic || raw);
    const count = used.get(baseKey) ?? 0;
    used.set(baseKey, count + 1);
    const key = count === 0 ? baseKey : `${baseKey}_${count + 1}`;
    return { key, raw, topic, subtopic };
  });
}


function isLikelySubheader(value: string): boolean {
  const key = canonicalizeKeySimple(value);
  return [
    "date",
    "startofwork",
    "endofwork",
    "breaktime",
    "workhours",
    "wellbeing",
    "diaryentry",
  ].includes(key);
}

export function parseHeaderRows(rawData: string[][]): HeaderParseResult {
  if (!rawData.length) {
    return { meta: [], dataStartIndex: 0, headerRows: [] };
  }

  const row1 = rawData[0] ?? [];
  const row2 = rawData[1] ?? [];
  const row1HasTopics = row1.filter((cell) => cell?.trim()).length >= 2;
  const row2HasLabels = row2.filter((cell) => cell?.trim()).length >= 2;

  if (row1HasTopics && row2HasLabels) {
    const used = new Map<string, number>();
    let lastTopic = "General";
    const meta = row2.map((sub, index) => {
      const rawTopic = (row1[index] || "").trim();
      const topic = rawTopic || lastTopic;
      if (rawTopic) lastTopic = rawTopic;
      const subtopic = (sub || "").trim();
      const raw = topic ? `${topic}::${subtopic || topic}` : subtopic || `Column ${index + 1}`;
      const baseKey = canonicalizeKeyWithContext(raw, topic, subtopic || raw);
      const count = used.get(baseKey) ?? 0;
      used.set(baseKey, count + 1);
      const key = count === 0 ? baseKey : `${baseKey}_${count + 1}`;
      return {
        key,
        raw,
        topic: topic || "General",
        subtopic: subtopic || raw,
      };
    });
    return {
      meta,
      dataStartIndex: 2,
      headerRows: [row1, row2],
    };
  }

  const meta = buildHeaderMeta(row1);
  return {
    meta,
    dataStartIndex: 1,
    headerRows: [row1],
  };
}

export function buildHeaderRowsFromMeta(
  meta: HeaderMeta[],
  style: "single" | "topic",
  dateFormat?: string,
): string[][] {
  if (style === "single") {
    return [meta.map((item) => item.raw)];
  }
  const topics: string[] = [];
  let lastTopic = "";
  meta.forEach((item) => {
    const topic = item.topic || "General";
    if (topic === lastTopic) {
      topics.push("");
    } else {
      topics.push(topic);
      lastTopic = topic;
    }
  });
  const subs = meta.map((item) => {
    if (item.key === "date" && dateFormat) return dateFormat;
    return item.subtopic || item.raw;
  });
  return [topics, subs];
}
