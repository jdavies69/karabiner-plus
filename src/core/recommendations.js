import { STARTER_RULE_PREFIX } from "./config.js";

export const recommendationPacks = [
  buildPack({
    id: "slack",
    title: "Slack",
    summary: "Slack quick-switch and composition helpers.",
    confidenceReason: "Slack is a frequent communication app with clear keyboard wins.",
    risk: "low",
    appMatchers: {
      bundleIdentifiers: ["com.tinyspeck.slackmacgap"],
      names: ["Slack"],
    },
    rules: [
      recommendationRule("Slack", ["com.tinyspeck.slackmacgap"], [
        {
          type: "basic",
          from: {
            key_code: "k",
            modifiers: {
              mandatory: ["right_command"],
              optional: ["any"],
            },
          },
          to: [
            {
              key_code: "k",
              modifiers: ["left_command"],
            },
          ],
        },
      ]),
    ],
  }),
  buildPack({
    id: "browser",
    title: "Browsers",
    summary: "Address bar and tab helpers for common browsers.",
    confidenceReason: "Browsers are heavily used and benefit from app-specific navigation.",
    risk: "low",
    appMatchers: {
      bundleIdentifiers: [
        "com.apple.Safari",
        "com.google.Chrome",
        "company.thebrowser.Browser",
        "org.mozilla.firefox",
      ],
      names: ["Safari", "Chrome", "Arc", "Firefox"],
    },
    rules: [
      recommendationRule(
        "Browsers",
        [
          "com.apple.Safari",
          "com.google.Chrome",
          "company.thebrowser.Browser",
          "org.mozilla.firefox",
        ],
        [
          {
            type: "basic",
            from: {
              key_code: "l",
              modifiers: {
                mandatory: ["right_command"],
                optional: ["any"],
              },
            },
            to: [
              {
                key_code: "l",
                modifiers: ["left_command"],
              },
            ],
          },
        ]
      ),
    ],
  }),
  buildPack({
    id: "messages",
    title: "Messages",
    summary: "Conversation navigation helpers for Messages.",
    confidenceReason: "Messaging apps reward quick app-local search and navigation.",
    risk: "low",
    appMatchers: {
      bundleIdentifiers: ["com.apple.MobileSMS"],
      names: ["Messages"],
    },
    rules: [
      recommendationRule("Messages", ["com.apple.MobileSMS"], [
        {
          type: "basic",
          from: {
            key_code: "f",
            modifiers: {
              mandatory: ["right_command"],
              optional: ["any"],
            },
          },
          to: [
            {
              key_code: "f",
              modifiers: ["left_command"],
            },
          ],
        },
      ]),
    ],
  }),
  buildPack({
    id: "media",
    title: "Media",
    summary: "Playback helpers for music and video apps.",
    confidenceReason: "Media apps work well with dedicated play and pause shortcuts.",
    risk: "low",
    appMatchers: {
      bundleIdentifiers: ["com.spotify.client", "com.apple.Music"],
      names: ["Spotify", "Music", "YouTube"],
    },
    rules: [
      recommendationRule("Media", ["com.spotify.client", "com.apple.Music"], [
        {
          type: "basic",
          from: {
            key_code: "spacebar",
            modifiers: {
              mandatory: ["right_command"],
              optional: ["any"],
            },
          },
          to: [
            {
              consumer_key_code: "play_or_pause",
            },
          ],
        },
      ]),
    ],
  }),
  buildPack({
    id: "preview",
    title: "Preview",
    summary: "Document navigation helpers for Preview.",
    confidenceReason: "Preview is a common document viewer and editor on macOS.",
    risk: "low",
    appMatchers: {
      bundleIdentifiers: ["com.apple.Preview"],
      names: ["Preview"],
    },
    rules: [
      recommendationRule("Preview", ["com.apple.Preview"], [
        {
          type: "basic",
          from: {
            key_code: "down_arrow",
            modifiers: {
              mandatory: ["right_command"],
              optional: ["any"],
            },
          },
          to: [
            {
              key_code: "page_down",
            },
          ],
        },
      ]),
    ],
  }),
];

export function normalizeUsageEntries(entries) {
  return (entries ?? [])
    .map((entry) => normalizeUsageEntry(entry))
    .filter(Boolean);
}

export function recommendPacksForUsage(entries) {
  const normalizedEntries = normalizeUsageEntries(entries);
  const scoredPacks = recommendationPacks.map((pack, index) => {
    let seconds = 0;
    let fitScore = 0;

    for (const entry of normalizedEntries) {
      const match = matchPackToUsage(pack, entry);
      if (!match) {
        continue;
      }

      seconds += entry.seconds;
      fitScore += entry.seconds * match.multiplier;
    }

    return {
      pack,
      index,
      seconds,
      fitScore,
    };
  });

  return scoredPacks
    .filter((score) => score.seconds > 0)
    .sort((left, right) => {
      if (right.seconds !== left.seconds) {
        return right.seconds - left.seconds;
      }

      if (right.fitScore !== left.fitScore) {
        return right.fitScore - left.fitScore;
      }

      return left.index - right.index;
    })
    .map(({ pack, seconds, fitScore }) => ({
      ...structuredClone(pack),
      seconds,
      fitScore,
    }));
}

export function rulesForRecommendationIds(ids) {
  const selected = new Set(ids ?? []);

  return recommendationPacks
    .filter((pack) => selected.has(pack.id))
    .flatMap((pack) => pack.rules.map((rule) => structuredClone(rule)));
}

function buildPack(pack) {
  return {
    ...pack,
    rules: pack.rules ?? [],
  };
}

function recommendationRule(label, bundleIdentifiers, manipulators) {
  return {
    description: `${STARTER_RULE_PREFIX} Recommended: ${label}`,
    conditions: [
      {
        type: "frontmost_application_if",
        bundle_identifiers: bundleIdentifiers,
      },
    ],
    manipulators,
  };
}

function normalizeUsageEntry(entry) {
  if (!entry || typeof entry !== "object") {
    return null;
  }

  const seconds = Number(entry.seconds);
  if (!Number.isFinite(seconds) || seconds <= 0) {
    return null;
  }

  const normalized = {
    seconds,
  };

  if (typeof entry.appName === "string" && entry.appName.trim()) {
    normalized.appName = entry.appName.trim();
  }

  if (typeof entry.bundleIdentifier === "string" && entry.bundleIdentifier.trim()) {
    normalized.bundleIdentifier = entry.bundleIdentifier.trim();
  }

  if (typeof entry.id === "string" && entry.id.trim()) {
    normalized.id = entry.id.trim();
  }

  if (typeof entry.lastSeenAt === "string" && entry.lastSeenAt.trim()) {
    normalized.lastSeenAt = entry.lastSeenAt.trim();
  }

  return normalized;
}

function matchPackToUsage(pack, entry) {
  const bundleIdentifier = entry.bundleIdentifier?.toLowerCase() ?? "";
  const appName = entry.appName?.toLowerCase() ?? "";
  const packId = entry.id?.toLowerCase() ?? "";
  const bundleIdentifiers = pack.appMatchers.bundleIdentifiers.map((value) => value.toLowerCase());
  const names = pack.appMatchers.names.map((value) => value.toLowerCase());

  if (bundleIdentifier && bundleIdentifiers.includes(bundleIdentifier)) {
    return { multiplier: 3 };
  }

  if (appName && names.includes(appName)) {
    return { multiplier: 2 };
  }

  if (packId && packId === pack.id.toLowerCase()) {
    return { multiplier: 1 };
  }

  return null;
}
