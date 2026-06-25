export function triggerForManipulator(manipulator) {
  if (!manipulator || manipulator.type !== "basic" || !manipulator.from) {
    return null;
  }

  const source =
    manipulator.from.key_code ??
    manipulator.from.consumer_key_code ??
    manipulator.from.pointing_button;

  if (!source) {
    return null;
  }

  const modifierSet = new Set(manipulator.from.modifiers?.mandatory ?? []);
  const modifiers = [...modifierSet].sort();

  return `key:${source}|mods:${modifiers.join("+")}`;
}

export function triggersForRule(rule) {
  return (rule.manipulators ?? [])
    .map((manipulator) => triggerEntryForManipulator(rule.description, manipulator))
    .filter(Boolean);
}

export function detectConflicts({ selectedRules, existingTriggers }) {
  const entries = [
    ...existingTriggers,
    ...selectedRules.flatMap((rule) => triggersForRule(rule)),
  ];
  const conflictMap = new Map();

  for (let i = 0; i < entries.length; i += 1) {
    for (let j = i + 1; j < entries.length; j += 1) {
      const a = entries[i];
      const b = entries[j];
      if (!triggersOverlap(a, b)) {
        continue;
      }

      const trigger = a.trigger === b.trigger
        ? a.trigger
        : `${a.trigger} overlaps ${b.trigger}`;
      appendTrigger(conflictMap, trigger, a.description);
      appendTrigger(conflictMap, trigger, b.description);
    }
  }

  return [...conflictMap.entries()]
    .map(([trigger, rules]) => ({
      trigger,
      rules,
    }));
}

function appendTrigger(triggerMap, trigger, description) {
  if (!triggerMap.has(trigger)) {
    triggerMap.set(trigger, []);
  }

  const rules = triggerMap.get(trigger);
  if (!rules.includes(description)) {
    rules.push(description);
  }
}

function triggerEntryForManipulator(description, manipulator) {
  const trigger = triggerForManipulator(manipulator);
  if (!trigger) {
    return null;
  }

  const entry = {
    description,
    trigger,
  };

  Object.defineProperty(entry, "details", {
    enumerable: false,
    value: triggerDetailsForManipulator(manipulator),
  });

  return entry;
}

function triggerDetailsForManipulator(manipulator) {
  const from = manipulator.from;
  return {
    source: from.key_code ?? from.consumer_key_code ?? from.pointing_button,
    mandatory: normalizeModifiers(from.modifiers?.mandatory ?? []),
    optional: normalizeModifiers(from.modifiers?.optional ?? []),
    optionalAny: (from.modifiers?.optional ?? []).includes("any"),
  };
}

function triggersOverlap(a, b) {
  const left = a.details ?? parseTrigger(a.trigger);
  const right = b.details ?? parseTrigger(b.trigger);

  if (!left || !right || left.source !== right.source) {
    return false;
  }

  for (const leftRequired of expandMandatory(left.mandatory)) {
    for (const rightRequired of expandMandatory(right.mandatory)) {
      const pressed = new Set([...leftRequired, ...rightRequired]);
      if (matchesModifierState(left, pressed) && matchesModifierState(right, pressed)) {
        return true;
      }
    }
  }

  return false;
}

function matchesModifierState(details, pressed) {
  for (const required of expandMandatory(details.mandatory)) {
    if ([...required].every((modifier) => pressed.has(modifier))) {
      return extrasAllowed(details, required, pressed);
    }
  }

  return false;
}

function extrasAllowed(details, required, pressed) {
  if (details.optionalAny) {
    return true;
  }

  const optionalConcrete = concreteModifierSet(details.optional);
  for (const modifier of pressed) {
    if (!required.has(modifier) && !optionalConcrete.has(modifier)) {
      return false;
    }
  }

  return true;
}

function expandMandatory(modifiers) {
  let sets = [new Set()];

  for (const modifier of modifiers) {
    const options = concreteOptionsForModifier(modifier);
    const next = [];
    for (const set of sets) {
      for (const option of options) {
        next.push(new Set([...set, ...option]));
      }
    }
    sets = next;
  }

  return sets;
}

function concreteModifierSet(modifiers) {
  return new Set(modifiers.flatMap((modifier) => concreteOptionsForModifier(modifier).flat()));
}

function concreteOptionsForModifier(modifier) {
  switch (normalizeModifier(modifier)) {
    case "command":
      return [["left_command"], ["right_command"]];
    case "control":
      return [["left_control"], ["right_control"]];
    case "option":
      return [["left_option"], ["right_option"]];
    case "shift":
      return [["left_shift"], ["right_shift"]];
    default:
      return [[normalizeModifier(modifier)]];
  }
}

function parseTrigger(trigger) {
  const match = trigger.match(/^key:(.+)\|mods:(.*)$/);
  if (!match) {
    return null;
  }

  return {
    source: match[1],
    mandatory: normalizeModifiers(match[2] ? match[2].split("+") : []),
    optional: [],
    optionalAny: true,
  };
}

function normalizeModifiers(modifiers) {
  return modifiers.filter((modifier) => modifier !== "any").map(normalizeModifier).sort();
}

function normalizeModifier(modifier) {
  switch (modifier) {
    case "left_alt":
      return "left_option";
    case "right_alt":
      return "right_option";
    case "left_gui":
      return "left_command";
    case "right_gui":
      return "right_command";
    default:
      return modifier;
  }
}
