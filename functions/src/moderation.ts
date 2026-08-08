/**
 * Content filtering for comments (App Store Guideline 1.2).
 *
 * The dictionary loads once at module scope, not per call. Matching
 * is whole-word/whole-phrase only, on a plain regular expression:
 * never a raw substring search. That distinction is the entire point
 * of this module. A naive substring check flags "Scunthorpe" for
 * containing "cunt" and "shiitake" for containing "shit". This app's
 * purpose is people writing about restaurants and dishes, so a filter
 * that cannot tell "Penistone" from "penis" is worse than no filter.
 *
 * leo-profanity's own check()/clean() do their own substring-based
 * matching internally, so this module does not call them. Only
 * leoProfanity.list() is used, as a plain word source, matched here
 * with an explicit \b-bounded pattern instead.
 *
 * leo-profanity's base dictionary is a single-word list, so it has
 * nothing for multi-word harassment or threats ("kill yourself", "i
 * know where you live"). Those are added explicitly below, the
 * "handful of obvious cases" a single-word dictionary cannot cover by
 * itself.
 */

import leoProfanity from "leo-profanity";

// A few slurs the base dictionary does not carry.
leoProfanity.add(["retard", "retarded"]);

// Multi-word harassment and threats: no single-word dictionary
// represents these, so they are listed explicitly.
const BANNED_PHRASES = [
  "kill yourself",
  "kys",
  "i will find you",
  "i know where you live",
];

/**
 * Escapes a string for safe use inside a RegExp pattern.
 * @param {string} value The raw string.
 * @return {string} The escaped string.
 */
function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

const dictionary = [...leoProfanity.list(), ...BANNED_PHRASES];
const bannedContentPattern = new RegExp(
  `\\b(${dictionary.map(escapeRegExp).join("|")})\\b`,
  "i"
);

/**
 * Checks whether text contains banned content: slurs, harassment,
 * threats, or sexual content. Matches whole words and phrases only.
 * @param {string} text The text to check.
 * @return {boolean} True if text contains banned content.
 */
export function containsBannedContent(text: string): boolean {
  return bannedContentPattern.test(text);
}
