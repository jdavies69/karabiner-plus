import assert from "node:assert/strict";
import test from "node:test";

import {
  normalizeUsageEntries,
  recommendationPacks,
  recommendPacksForUsage,
  rulesForRecommendationIds,
} from "../src/core/recommendations.js";

test("recommendation pack catalog includes Slack, browser, and media packs", () => {
  const ids = recommendationPacks.map((pack) => pack.id);

  assert.ok(ids.includes("slack"));
  assert.ok(ids.includes("browser"));
  assert.ok(ids.includes("media"));
  assert.ok(ids.includes("messages"));
  assert.ok(ids.includes("preview"));
});

test("normalizeUsageEntries drops zero-time usage and keeps the rest", () => {
  assert.deepEqual(
    normalizeUsageEntries([
      {
        appName: "Slack",
        bundleIdentifier: "com.tinyspeck.slackmacgap",
        seconds: 120,
        lastSeenAt: "2026-06-25T12:00:00.000Z",
      },
      {
        appName: "Safari",
        bundleIdentifier: "com.apple.Safari",
        seconds: 0,
        lastSeenAt: "2026-06-25T12:05:00.000Z",
      },
      {
        appName: "Spotify",
        bundleIdentifier: "com.spotify.client",
        seconds: 45,
        lastSeenAt: "2026-06-25T12:10:00.000Z",
      },
    ]),
    [
      {
        appName: "Slack",
        bundleIdentifier: "com.tinyspeck.slackmacgap",
        seconds: 120,
        lastSeenAt: "2026-06-25T12:00:00.000Z",
      },
      {
        appName: "Spotify",
        bundleIdentifier: "com.spotify.client",
        seconds: 45,
        lastSeenAt: "2026-06-25T12:10:00.000Z",
      },
    ]
  );
});

test("recommendPacksForUsage ranks the most-used packs first", () => {
  assert.deepEqual(
    recommendPacksForUsage([
      { appName: "Spotify", bundleIdentifier: "com.spotify.client", seconds: 5 },
      { appName: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap", seconds: 15 },
      { appName: "Safari", bundleIdentifier: "com.apple.Safari", seconds: 10 },
    ])
      .slice(0, 3)
      .map((pack) => pack.id),
    ["slack", "browser", "media"]
  );
});

test("recommendPacksForUsage omits packs with no matching usage", () => {
  assert.deepEqual(
    recommendPacksForUsage([
      { appName: "Calculator", bundleIdentifier: "com.apple.calculator", seconds: 120 },
    ]),
    []
  );
});

test("rulesForRecommendationIds returns recommended rules with app conditions", () => {
  const rules = rulesForRecommendationIds(["slack"]);

  assert.equal(rules.length, 1);
  assert.equal(rules[0].description, "[Karabiner+] Recommended: Slack");
  assert.deepEqual(rules[0].conditions, [
    {
      type: "frontmost_application_if",
      bundle_identifiers: ["com.tinyspeck.slackmacgap"],
    },
  ]);
  assert.ok(rules[0].manipulators.length > 0);
});
