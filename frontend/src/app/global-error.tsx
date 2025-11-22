'use client';

import { AlertTriangle, RefreshCw } from 'lucide-react';

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html>
      <body>
        <div className="min-h-screen flex items-center justify-center bg-gray-50 p-4">
          <div className="max-w-lg w-full bg-white rounded-lg shadow-lg p-8">
            <div className="flex items-center gap-3 mb-6">
              <AlertTriangle className="h-8 w-8 text-red-500" />
              <div>
                <h2 className="text-2xl font-bold text-gray-900">Critical Error</h2>
                <p className="text-gray-600">A critical error occurred in the application</p>
              </div>
            </div>

            <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
              <p className="text-sm font-mono text-red-900 break-all">
                {error.message || 'An unexpected error occurred'}
              </p>
            </div>

            <button
              onClick={reset}
              className="w-full flex items-center justify-center gap-2 bg-primary-600 text-white px-4 py-3 rounded-lg hover:bg-primary-700 transition"
            >
              <RefreshCw className="h-4 w-4" />
              Try Again
            </button>
          </div>
        </div>
      </body>
    </html>
  );
}
