import {containsBannedContent} from "./moderation";

describe("containsBannedContent", () => {
  describe("must block", () => {
    test.each([
      "nigger",
      "faggot",
      "cunt",
      "kike",
      "retard",
      "retarded",
      "pedophile",
      "rapist",
    ])("blocks slur/sexual-content term: %s", (word) => {
      expect(containsBannedContent(word)).toBe(true);
      expect(containsBannedContent(`this ${word} thing happened`)).toBe(true);
    });

    test.each([
      "you are a worthless piece of shit",
      "everyone here thinks you are retarded",
      "kill yourself",
      "kys",
      "i will find you",
      "i know where you live",
      "suck my dick",
      "go rape yourself",
    ])("blocks obvious harassment/threat/sexual case: %s", (text) => {
      expect(containsBannedContent(text)).toBe(true);
    });
  });

  describe("must not block", () => {
    test.each([
      "Mensho",
      "CorkScrew BBQ",
      "ChòpnBlọk",
      "The Monk's",
      "Lotus Seafood",
      "Tacos Los Brothers",
    ])("does not block restaurant name: %s", (name) => {
      expect(containsBannedContent(name)).toBe(false);
      expect(containsBannedContent(`We ate at ${name} last night`)).toBe(
        false
      );
    });

    test.each([
      "suya",
      "jollof",
      "waakye",
      "egusi",
      "buka",
      "korma",
      "saag",
      "tikka masala",
      "turkey neck",
      "crack sauce",
      "shiitake",
    ])("does not block dish name: %s", (dish) => {
      expect(containsBannedContent(dish)).toBe(false);
      expect(containsBannedContent(`The ${dish} here is amazing`)).toBe(
        false
      );
    });

    test.each([
      "Scunthorpe",
      "assassin",
      "class",
      "analysis",
      "Hancock",
      "Penistone",
      "grape",
      "cockerel",
    ])("does not block classic substring trap: %s", (word) => {
      expect(containsBannedContent(word)).toBe(false);
      expect(containsBannedContent(`I visited ${word} once`)).toBe(false);
    });

    test.each([
      "damn good",
      "this is sick",
      "stupid good",
      "hell of a sandwich",
    ])("does not block mild profanity used as praise: %s", (phrase) => {
      expect(containsBannedContent(phrase)).toBe(false);
      expect(containsBannedContent(`That was ${phrase}, honestly`)).toBe(
        false
      );
    });
  });
});
