'use client';

import { useEffect, useRef } from 'react';
import anime from 'animejs';
import { motion } from 'framer-motion';

interface PageTransitionProps {
  children: React.ReactNode;
}

export function PageTransition({ children }: PageTransitionProps) {
  const pageRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (pageRef.current) {
      // Anime.js entrance animation
      anime({
        targets: pageRef.current,
        opacity: [0, 1],
        translateY: [20, 0],
        duration: 600,
        easing: 'easeOutExpo',
      });

      // Animate child elements with stagger
      const children = pageRef.current.querySelectorAll('.animate-in');
      if (children.length > 0) {
        anime({
          targets: children,
          opacity: [0, 1],
          translateY: [30, 0],
          delay: anime.stagger(100),
          duration: 800,
          easing: 'easeOutExpo',
        });
      }
    }
  }, []);

  return (
    <div ref={pageRef} style={{ opacity: 0 }}>
      {children}
    </div>
  );
}

// Animated card component
export function AnimatedCard({ children, delay = 0 }: { children: React.ReactNode; delay?: number }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20, scale: 0.95 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{
        duration: 0.5,
        delay,
        ease: [0.25, 0.1, 0.25, 1],
      }}
      whileHover={{ y: -4, transition: { duration: 0.2 } }}
    >
      {children}
    </motion.div>
  );
}

// Stagger children animation
export function StaggerContainer({ children, staggerDelay = 0.1 }: { children: React.ReactNode; staggerDelay?: number }) {
  return (
    <motion.div
      initial="hidden"
      animate="visible"
      variants={{
        visible: {
          transition: {
            staggerChildren: staggerDelay,
          },
        },
      }}
    >
      {children}
    </motion.div>
  );
}

// Individual stagger item
export function StaggerItem({ children }: { children: React.ReactNode }) {
  return (
    <motion.div
      variants={{
        hidden: { opacity: 0, y: 20 },
        visible: { opacity: 1, y: 0 },
      }}
      transition={{ duration: 0.5, ease: 'easeOut' }}
    >
      {children}
    </motion.div>
  );
}
