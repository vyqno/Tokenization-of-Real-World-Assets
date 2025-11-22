'use client';

import Link from 'next/link';
import { ConnectButton } from "thirdweb/react";
import { client } from "@/lib/thirdweb";
import { ACTIVE_CHAIN } from "@/lib/config";
import { Building2, LayoutDashboard, ShoppingCart, Vote, TrendingUp, ArrowDownUp, Droplet } from 'lucide-react';
import { ThemeToggle } from './ThemeToggle';
import { MobileNav } from './MobileNav';

export function Navbar() {
  return (
    <nav className="border-b border-gray-200 dark:border-gray-700 bg-white/80 dark:bg-gray-900/80 backdrop-blur-md sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          <div className="flex items-center space-x-8">
            <Link href="/" className="flex items-center space-x-2">
              <Building2 className="h-8 w-8 text-primary-600" />
              <span className="text-xl font-bold text-gray-900 dark:text-white">RWA Platform</span>
            </Link>

            <div className="hidden md:flex space-x-6">
              <Link
                href="/marketplace"
                className="flex items-center space-x-1 text-gray-700 dark:text-gray-300 hover:text-primary-600 dark:hover:text-primary-400 transition"
              >
                <ShoppingCart className="h-4 w-4" />
                <span>Marketplace</span>
              </Link>

              <Link
                href="/swap"
                className="flex items-center space-x-1 text-gray-700 dark:text-gray-300 hover:text-primary-600 dark:hover:text-primary-400 transition"
              >
                <ArrowDownUp className="h-4 w-4" />
                <span>Swap</span>
              </Link>

              <Link
                href="/register"
                className="flex items-center space-x-1 text-gray-700 dark:text-gray-300 hover:text-primary-600 dark:hover:text-primary-400 transition"
              >
                <Building2 className="h-4 w-4" />
                <span>Register Property</span>
              </Link>

              <Link
                href="/portfolio"
                className="flex items-center space-x-1 text-gray-700 dark:text-gray-300 hover:text-primary-600 dark:hover:text-primary-400 transition"
              >
                <LayoutDashboard className="h-4 w-4" />
                <span>Portfolio</span>
              </Link>

              <Link
                href="/governance"
                className="flex items-center space-x-1 text-gray-700 dark:text-gray-300 hover:text-primary-600 dark:hover:text-primary-400 transition"
              >
                <Vote className="h-4 w-4" />
                <span>Governance</span>
              </Link>

              <Link
                href="/analytics"
                className="flex items-center space-x-1 text-gray-700 dark:text-gray-300 hover:text-primary-600 dark:hover:text-primary-400 transition"
              >
                <TrendingUp className="h-4 w-4" />
                <span>Analytics</span>
              </Link>

              <Link
                href="/liquidity"
                className="flex items-center space-x-1 text-gray-700 dark:text-gray-300 hover:text-primary-600 dark:hover:text-primary-400 transition"
              >
                <Droplet className="h-4 w-4" />
                <span>Liquidity</span>
              </Link>
            </div>
          </div>

          <div className="flex items-center gap-4">
            <ThemeToggle />
            <div className="hidden md:block">
              <ConnectButton
                client={client}
                chain={ACTIVE_CHAIN}
                connectModal={{
                  size: "compact",
                }}
              />
            </div>
            <MobileNav />
          </div>
        </div>
      </div>
    </nav>
  );
}
