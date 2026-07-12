import { describe, expect, test } from "bun:test";
import { startMdnsAdvertisement, type MdnsResponder } from "../src/relay/mdns";

class FakeMdnsResponder implements MdnsResponder {
  queryHandler: ((query: { questions: Array<{ name: string; type: string }> }) => void) | undefined;
  responses: unknown[][] = [];
  destroyed = false;

  on(event: "query", handler: (query: { questions: Array<{ name: string; type: string }> }) => void) {
    this.queryHandler = handler;
  }

  respond(records: unknown[]) {
    this.responses.push(records);
  }

  destroy() {
    this.destroyed = true;
  }
}

describe("mDNS advertisement", () => {
  test("responds with Vidyut service records", () => {
    const responder = new FakeMdnsResponder();
    const stop = startMdnsAdvertisement({
      responder,
      instanceName: "Vidyut Laptop",
      hostName: "vidyut-laptop",
      port: 17321,
      addresses: ["192.168.1.10"],
    });

    responder.queryHandler?.({
      questions: [{ name: "_vidyut._tcp.local", type: "PTR" }],
    });

    expect(responder.responses.at(-1)).toEqual([
      { name: "_vidyut._tcp.local", type: "PTR", ttl: 120, data: "Vidyut Laptop._vidyut._tcp.local" },
      {
        name: "Vidyut Laptop._vidyut._tcp.local",
        type: "SRV",
        ttl: 120,
        data: { priority: 0, weight: 0, port: 17321, target: "vidyut-laptop.local" },
      },
      {
        name: "Vidyut Laptop._vidyut._tcp.local",
        type: "TXT",
        ttl: 120,
        data: ["v=1", "service=vidyut"],
      },
      { name: "vidyut-laptop.local", type: "A", ttl: 120, data: "192.168.1.10" },
    ]);

    stop();
    expect(responder.destroyed).toBe(true);
  });

  test("does not answer unrelated mDNS questions", () => {
    const responder = new FakeMdnsResponder();
    startMdnsAdvertisement({
      responder,
      instanceName: "Vidyut Laptop",
      hostName: "vidyut-laptop",
      port: 17321,
      addresses: ["192.168.1.10"],
    });
    const announcements = responder.responses.length;

    responder.queryHandler?.({
      questions: [{ name: "printer.local", type: "A" }],
    });

    expect(responder.responses).toHaveLength(announcements);
  });
});
