/**
 * Logging library for Svelte frontend
 *
 * Usage:
 * import * as logging from '$lib/logging';
 * 
 * Optionally: 
 * logging.setLogLevelFromEnvironment();
 * to set the log level from the environment (but will be auto-run once if not called)
 * or
 * logging.setLogLevel('debug');
 * to set the log level manually
 * or
 * logging.setLogLevel('warn');
 * to set the log level to warn
 * 
 * Then:
 * logging.debug('This is a debug message', some, objects);
 * logging.info('This is an info message');
 * logging.warn('This is a warn message');
 * logging.error('This is an error message');
 */


let logLevel = 2;

let logLevelSet = false;

const LOG_LEVELS = {
  'debug': 0,
  'info': 1,
  'warn': 2,
  'error': 3,
};

export function setLogLevelFromEnvironment(force) {
  console.log("Setting log level from environment (force: " + force + ")");
  if (force != null) {
    setLogLevel(force);
    debug("Log level forced to " + force + " (" + logLevel + ")");
  } else if (window.location.hostname.includes('localhost')) {
    setLogLevel('debug');
    debug("Localhost detected (hostname: " + window.location.hostname + "), setting log level to debug (" + logLevel + ")");
  } else {
    setLogLevel('warn');
  }
}

export function setLogLevel(level) {
  logLevel = logLevelToNumber(level);
  logLevelSet = true;
}

export function getLogLevel() {
  return numberToLogLevel(logLevel);
}

export function log(level, ...message) {
  if (!logLevelSet) {
    setLogLevelFromEnvironment();
  }
  if (logLevelToNumber(level) >= logLevel) {
    if (level === 'error') {
      console.error("ERROR", ...message);
    } else if (level === 'warn') {
      console.warn("WARN", ...message);
    } else if (level === 'info') {
      console.info("INFO", ...message);
    } else if (level === 'debug') {
      console.debug("DEBUG", ...message);
    }    
  }
}

export function debug(...message) {
  log('debug', ...message);
}

export function info(...message) {
  log('info', ...message);
}

export function warn(...message) {
  log('warn', ...message);
}

export function error(...message) {
  log('error', ...message);
}

function logLevelToNumber(level) {
  return LOG_LEVELS[level];
}

function numberToLogLevel(number) {
  return Object.keys(LOG_LEVELS).find((key) => LOG_LEVELS[key] === number);
}