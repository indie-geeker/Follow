const double desktopNavigationBreakpoint = 800;

enum MobileNavigationDestination { home, library, downloads, settings }

const mobileNavigationDestinations = <MobileNavigationDestination>[
  MobileNavigationDestination.home,
  MobileNavigationDestination.library,
  MobileNavigationDestination.downloads,
  MobileNavigationDestination.settings,
];

bool usesDesktopNavigation(double width) =>
    width >= desktopNavigationBreakpoint;
