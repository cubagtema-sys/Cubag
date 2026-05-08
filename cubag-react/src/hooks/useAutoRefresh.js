import { useEffect, useRef } from 'react'

/**
 * Automatically calls `fetchFn` on mount and then every `intervalMs` milliseconds.
 * Stops when the component unmounts.
 *
 * @param {Function} fetchFn   - The async fetch function to call periodically
 * @param {number}   intervalMs - How often to refresh in ms (default: 30 seconds)
 * @param {Array}    deps       - Extra dependencies that should restart the interval
 */
export default function useAutoRefresh(fetchFn, intervalMs = 30000, deps = []) {
  const savedFn = useRef(fetchFn)

  // Keep ref up-to-date without restarting the interval
  useEffect(() => {
    savedFn.current = fetchFn
  }, [fetchFn])

  useEffect(() => {
    // Run immediately on mount
    savedFn.current()

    // Then run on interval
    const id = setInterval(() => savedFn.current(), intervalMs)

    // Cleanup on unmount
    return () => clearInterval(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [intervalMs, ...deps])
}
