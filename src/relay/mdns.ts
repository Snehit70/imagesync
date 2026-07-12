import multicastDns from "multicast-dns";

export interface MdnsQuestion {
  name: string;
  type: string;
}

export interface MdnsResponder {
  on(event: "query", handler: (query: { questions: MdnsQuestion[] }) => void): void;
  respond(records: MdnsRecord[]): void;
  destroy(): void;
}

export type MdnsRecord =
  | { name: string; type: "PTR"; ttl: number; data: string }
  | { name: string; type: "SRV"; ttl: number; data: { priority: number; weight: number; port: number; target: string } }
  | { name: string; type: "TXT"; ttl: number; data: string[] }
  | { name: string; type: "A"; ttl: number; data: string };

interface MdnsAdvertisementOptions {
  responder?: MdnsResponder;
  instanceName: string;
  hostName: string;
  port: number;
  addresses: string[];
}

const serviceName = "_vidyut._tcp.local";

export function startMdnsAdvertisement(options: MdnsAdvertisementOptions): () => void {
  const responder = options.responder ?? (multicastDns() as MdnsResponder);
  const records = createServiceRecords(options);
  const answerableNames = new Set(records.map((record) => record.name));

  responder.on("query", (query) => {
    if (query.questions.some((question) => answerableNames.has(question.name))) {
      responder.respond(records);
    }
  });
  responder.respond(records);

  return () => {
    responder.destroy();
  };
}

function createServiceRecords(options: MdnsAdvertisementOptions): MdnsRecord[] {
  const instanceServiceName = `${options.instanceName}.${serviceName}`;
  const target = `${options.hostName}.local`;
  return [
    { name: serviceName, type: "PTR", ttl: 120, data: instanceServiceName },
    {
      name: instanceServiceName,
      type: "SRV",
      ttl: 120,
      data: { priority: 0, weight: 0, port: options.port, target },
    },
    {
      name: instanceServiceName,
      type: "TXT",
      ttl: 120,
      data: ["v=1", "service=vidyut"],
    },
    ...options.addresses.map((address): MdnsRecord => ({ name: target, type: "A", ttl: 120, data: address })),
  ];
}
