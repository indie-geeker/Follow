# Mobile Player Direct-Manipulation Correction Design

**Date:** 2026-09-01

## Goal

Correct the mobile player's spatial model so every gesture directly manipulates
the layer it reveals: cardinal-axis record movement, a real playlist page above
the player, a queue of small records below the main record, and ViewPager-like
record/lyrics transitions.

## Gesture Arbitration

The record begins each pan undecided. After cumulative movement reaches 10dp,
it locks to the dominant horizontal or vertical axis. Only the locked component
is rendered and used for completion; diagonal movement never appears. A 56dp
distance or qualified fling completes the gesture.

- vertical up/down changes track and returns the record to rest;
- horizontal left from the record drives the record/lyrics page transition;
- horizontal right from the record moves only the record and reveals its queue;
- horizontal right from lyrics reverses the ViewPager transition to the record.

## Record and Lyrics Pager

Record and lyrics occupy adjacent horizontal pages in one viewport. While the
record is dragged left, it exits to the left and lyrics enters from the right at
the same progress. Releasing beyond threshold settles on lyrics; otherwise both
pages return. The reverse gesture on lyrics follows the finger and settles back
to the record. Lyrics retain ownership of vertical scrolling.

## Playlist Page

The playlist gallery is a persistent page located above the entire player page.
The player `Scaffold`, including its app bar, translates down during a top-handle
drag, revealing the playlist page behind it. There is no scrim, popup elevation,
rounded popup edge, or overlay dismissal area. Release settles the player at
zero or at the playlist-page height. Selecting a playlist plays it and slides
the player back up.

## Queue Reveal

The track queue is always painted below the main record. It contains only small
circular track covers positioned along a loose vertical orbit; it has no card,
title, close button, or track text. The record's horizontal position controls
queue opacity and visible extent continuously. Completing a right drag rests the
record on the right. A left drag returns it to center and covers the queue again.
Queue covers remain tappable once the reveal is settled.

## Accessibility and Motion

Visible previous/next and queue controls remain. Record and queue covers retain
semantic labels. Reduced-motion mode removes decorative translation animation,
but state changes and direct selection remain available. System back first
closes the playlist page, lyrics page, or queue reveal.

## Verification

Widget tests must prove axis locking during the drag, continuous queue reveal,
transparent cover-only queue styling, ViewPager intermediate positions, player
page displacement by the playlist height, selection collapse, back behavior,
small portrait layout, landscape layout, and reduced motion. Then run scoped
tests, full analysis, full Flutter tests, and an Android debug build.
