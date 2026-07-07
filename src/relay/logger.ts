import type { LogLevel } from "./config";

const levelWeight: Record<LogLevel, number> = {
  debug: 10,
  info: 20,
  warn: 30,
  error: 40,
};

export interface Logger {
  debug(message: string, fields?: Record<string, unknown>): void;
  info(message: string, fields?: Record<string, unknown>): void;
  warn(message: string, fields?: Record<string, unknown>): void;
  error(message: string, fields?: Record<string, unknown>): void;
}

export function createLogger(level: LogLevel): Logger {
  return {
    debug: (message, fields) => writeLog(level, "debug", message, fields),
    info: (message, fields) => writeLog(level, "info", message, fields),
    warn: (message, fields) => writeLog(level, "warn", message, fields),
    error: (message, fields) => writeLog(level, "error", message, fields),
  };
}

function writeLog(configuredLevel: LogLevel, level: LogLevel, message: string, fields: Record<string, unknown> = {}): void {
  if (levelWeight[level] < levelWeight[configuredLevel]) return;
  console.log(
    JSON.stringify({
      ts: new Date().toISOString(),
      level,
      message,
      ...fields,
    }),
  );
}

