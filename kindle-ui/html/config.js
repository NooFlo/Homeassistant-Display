// Dashboard configuration. Everything user-specific lives here.
// The UI app reads this; you never need to touch index.html.
//
// panelW/panelH: Kindle panel resolution in PORTRAIT pixels
// (the app rotates the layout 90 degrees for a landscape dashboard).

var CONFIG = {
  locationLabel: 'Home',
  lat: 52.52,
  lon: 13.405,
  timezone: 'Europe/Berlin',
  // Defaults target the Kindle Paperwhite 11 (EY21, 2021): 1236x1648.
  // Other models: see docs/MODELS.md.
  panelW: 1236,
  panelH: 1648,
  // Seconds without a touch before the app switches to the sleep view.
  // The on-device sleep job suspends independently of this; the sleep
  // view just makes the frozen image honest about its state.
  idleSeconds: 150
};

// Rooms and devices. One device per line; the interactive helpers in
// scripts/ can manage these entries for you.
//
// Supported types:
//   toggle  - lights, switches, fans (on/off)
//   climate - mode buttons from the entity's hvac_modes + setpoint stepper
//   lock    - lock/unlock
//   sensor  - read-only value display
//
// { type: 'toggle', name: 'Ceiling', entity: 'light.kitchen_ceiling' }

var ROOMS = [
  {
    name: 'Living Room',
    devices: [
      { type: 'toggle', name: 'Ceiling', entity: 'light.living_room_ceiling' },
      { type: 'sensor', name: 'Temp', entity: 'sensor.living_room_temperature' }
    ]
  },
  {
    name: 'Bedroom',
    devices: [
      { type: 'toggle', name: 'Bedside', entity: 'light.bedside' }
    ]
  }
];
