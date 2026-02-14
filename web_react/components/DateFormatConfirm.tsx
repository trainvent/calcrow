"use client";

import { DateFormatKey } from "@/lib/csv";

interface DateFormatConfirmProps {
  detected: DateFormatKey | null;
  candidates: DateFormatKey[];
  selected: DateFormatKey | "";
  onSelect: (format: DateFormatKey) => void;
}

const ALL_FORMATS: DateFormatKey[] = [
  "YYYY-MM-DD",
  "DD/MM/YYYY",
  "MM/DD/YYYY",
  "YYYY/MM/DD",
  "DD.MM.YYYY",
];

export function DateFormatConfirm({
  detected,
  candidates,
  selected,
  onSelect,
}: DateFormatConfirmProps) {
  const options = candidates.length > 0 ? candidates : ALL_FORMATS;

  return (
    <div className="card">
      <div className="kicker">Date format</div>
      <p>
        {detected
          ? `Detected format: ${detected}. Confirm or choose another.`
          : "We found multiple date formats. Please confirm the right one."}
      </p>
      <select
        value={selected}
        onChange={(event) => onSelect(event.target.value as DateFormatKey)}
      >
        <option value="">Select format</option>
        {options.map((format) => (
          <option key={format} value={format}>
            {format}
          </option>
        ))}
      </select>
    </div>
  );
}
