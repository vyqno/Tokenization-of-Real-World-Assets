'use client';

import { Github, Twitter, FileText } from 'lucide-react';

export function Footer() {
  return (
    <footer className="border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
          <div className="col-span-1 md:col-span-2">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">
              RWA Tokenization Platform
            </h3>
            <p className="text-gray-600 dark:text-gray-400 mb-4">
              Tokenize physical land into ERC-20s, run a capped primary sale,
              seed DEX liquidity, and govern the asset through staking-backed verification.
            </p>
            <div className="flex space-x-4">
              <a
                href="https://github.com"
                target="_blank"
                rel="noopener noreferrer"
                className="text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition"
              >
                <Github className="h-5 w-5" />
              </a>
              <a
                href="https://twitter.com"
                target="_blank"
                rel="noopener noreferrer"
                className="text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition"
              >
                <Twitter className="h-5 w-5" />
              </a>
            </div>
          </div>

          <div>
            <h4 className="text-sm font-semibold text-gray-900 dark:text-white mb-4">Resources</h4>
            <ul className="space-y-2">
              <li>
                <a href="/docs" className="text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition">
                  Documentation
                </a>
              </li>
              <li>
                <a href="/protocol" className="text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition">
                  Protocol Guide
                </a>
              </li>
              <li>
                <a href="/tokenomics" className="text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition">
                  Tokenomics
                </a>
              </li>
            </ul>
          </div>

          <div>
            <h4 className="text-sm font-semibold text-gray-900 dark:text-white mb-4">Legal</h4>
            <ul className="space-y-2">
              <li>
                <a href="/terms" className="text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition">
                  Terms of Service
                </a>
              </li>
              <li>
                <a href="/privacy" className="text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition">
                  Privacy Policy
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-8 pt-8 border-t border-gray-200 dark:border-gray-700">
          <p className="text-center text-gray-600 dark:text-gray-400 text-sm">
            © {new Date().getFullYear()} RWA Tokenization Platform. All rights reserved.
          </p>
        </div>
      </div>
    </footer>
  );
}
