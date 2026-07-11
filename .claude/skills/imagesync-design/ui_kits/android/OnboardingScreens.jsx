// Onboarding wizard screens — from onboarding_wizard.dart (copy verbatim, D7).
const DS2 = window.ImageSyncDesignSystem_5c35fc;

function StepScaffold({ icon, title, body, consequence, primaryLabel, onPrimary, onSkip, stepIndex, stepCount }) {
  const { MorphingBlob, PressableScale, Button, Entrance } = DS2;
  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "16px 24px 24px", minHeight: 0 }}>
      <window.StepDots count={stepCount} index={stepIndex} />
      <div style={{ flex: 1 }}></div>
      <Entrance index={0}>
        <div style={{ display: "grid", placeItems: "center" }}>
          <MorphingBlob size={150}>
            <div style={{ width: 64, height: 64, background: "#fff", borderRadius: "50%", display: "grid", placeItems: "center" }}>
              <span className="material-icons-outlined" style={{ fontSize: 28, color: "var(--raspberry)" }}>{icon}</span>
            </div>
          </MorphingBlob>
        </div>
      </Entrance>
      <div style={{ height: 28 }}></div>
      <Entrance index={1}>
        <div style={{ textAlign: "center", fontSize: 26, fontWeight: 800, letterSpacing: "-0.78px" }}>{title}</div>
      </Entrance>
      <div style={{ height: 12 }}></div>
      <Entrance index={2}>
        <div style={{ textAlign: "center", fontSize: 14, fontWeight: 500, color: "var(--muted)", lineHeight: 1.3 }}>{body}</div>
      </Entrance>
      <div style={{ flex: 1 }}></div>
      <Entrance index={3}>
        <div style={{ textAlign: "center", fontSize: 12, fontWeight: 500, color: "var(--muted)", lineHeight: 1.3 }}>
          If you skip: {consequence}
        </div>
      </Entrance>
      <div style={{ height: 14 }}></div>
      <Entrance index={4}>
        <PressableScale><Button onClick={onPrimary}>{primaryLabel}</Button></PressableScale>
      </Entrance>
      <div style={{ height: 6 }}></div>
      <Entrance index={5}>
        <div style={{ display: "grid", placeItems: "center" }}>
          <Button variant="text" muted fullWidth={false} onClick={onSkip}>Skip</Button>
        </div>
      </Entrance>
    </div>
  );
}

const wizardSteps = [
  {
    icon: "notifications_active",
    title: "Stay in the loop",
    body: "ImageSync shows a small ongoing notification while sync runs, and a quiet receipt when something arrives from your laptop.",
    consequence: "You won't see receipts when the laptop sends you things.",
    primaryLabel: "Allow",
  },
  {
    icon: "photo_library",
    title: "Spot your screenshots",
    body: "To send screenshots automatically, ImageSync needs access to all photos. Pick Allow all — with 'Select photos' it can't see new screenshots.",
    consequence: "Screenshots won't send themselves — you can still share manually.",
    primaryLabel: "Allow access",
  },
  {
    icon: "battery_charging_full",
    title: "Keep the link alive",
    body: "Android puts idle apps to sleep, which drops the connection to your laptop. Allow ImageSync to ignore battery optimizations so payloads arrive even when the screen is off.",
    consequence: "Sync may pause when the phone sleeps.",
    primaryLabel: "Allow",
  },
];

function PairingFinale({ paired, connected, onPair, onDone, stepCount }) {
  const { MorphingBlob, RippleRings, PressableScale, Button, Entrance, NearbyRelaysCard, ManualPairingForm } = DS2;
  const [host, setHost] = React.useState("");
  const [port, setPort] = React.useState("17321");
  const [secret, setSecret] = React.useState("");
  const [selected, setSelected] = React.useState(null);
  const relays = [{ name: "imagesync-relay", host: "192.168.1.4", port: 17321 }];

  if (paired) {
    return (
      <div style={{ flex: 1, display: "flex", flexDirection: "column", justifyContent: "center", padding: "16px 24px 24px" }}>
        <Entrance index={0}>
          <div style={{ display: "grid", placeItems: "center" }}>
            <RippleRings size={160}>
              <div style={{ width: 72, height: 72, background: "var(--raspberry)", borderRadius: "50%", display: "grid", placeItems: "center" }}>
                <span className="material-icons" style={{ fontSize: 32, color: "#fff" }}>{connected ? "link" : "wifi_find"}</span>
              </div>
            </RippleRings>
          </div>
        </Entrance>
        <div style={{ height: 24 }}></div>
        <Entrance index={1}>
          <div style={{ textAlign: "center", fontSize: 26, fontWeight: 800, letterSpacing: "-0.78px" }}>
            {connected ? "Connected" : "Connecting…"}
          </div>
        </Entrance>
        <div style={{ height: 8 }}></div>
        <Entrance index={2}>
          <div style={{ textAlign: "center", fontSize: 14, fontWeight: 500, color: "var(--muted)" }}>
            {connected ? "Your laptop and phone are in sync." : "Paired — waiting for the relay."}
          </div>
        </Entrance>
        <div style={{ height: 32 }}></div>
        <Entrance index={3}>
          <PressableScale><Button onClick={onDone}>Done</Button></PressableScale>
        </Entrance>
      </div>
    );
  }

  return (
    <div style={{ flex: 1, overflowY: "auto", padding: "16px 24px 24px", minHeight: 0 }}>
      <window.StepDots count={stepCount} index={stepCount - 1} />
      <div style={{ height: 24 }}></div>
      <Entrance index={0}>
        <div style={{ fontSize: 26, fontWeight: 800, letterSpacing: "-0.78px" }}>Connect to your laptop</div>
      </Entrance>
      <div style={{ height: 10 }}></div>
      <Entrance index={1}>
        <div style={{ fontSize: 14, fontWeight: 500, color: "var(--muted)", lineHeight: 1.3 }}>
          Run the relay on your laptop, then pick it below or scan its QR code.
        </div>
      </Entrance>
      <div style={{ height: 20 }}></div>
      <Entrance index={2}>
        <NearbyRelaysCard
          relays={relays}
          selected={selected}
          discovering={false}
          onRefresh={() => {}}
          onSelect={(r) => { setSelected(r); setHost(r.host); setPort(String(r.port)); }}
        />
      </Entrance>
      <div style={{ height: 24 }}></div>
      <Entrance index={3}>
        <ManualPairingForm
          host={host} port={port} secret={secret}
          onHostChange={setHost} onPortChange={setPort} onSecretChange={setSecret}
          error={null} onPair={onPair} onScanQr={onPair}
        />
      </Entrance>
      <div style={{ height: 12 }}></div>
      <Entrance index={4}>
        <div style={{ display: "grid", placeItems: "center" }}>
          <Button variant="text" fullWidth={false} onClick={onDone}>Skip for now</Button>
        </div>
      </Entrance>
    </div>
  );
}

function OnboardingFlow({ onFinish }) {
  const [step, setStep] = React.useState(0);
  const [paired, setPaired] = React.useState(false);
  const stepCount = 4;
  const next = () => setStep((s) => s + 1);

  if (step < 3) {
    const s = wizardSteps[step];
    return (
      <StepScaffold
        key={step}
        {...s}
        stepIndex={step}
        stepCount={stepCount}
        onPrimary={next}
        onSkip={next}
      />
    );
  }
  return (
    <PairingFinale
      paired={paired}
      connected={true}
      stepCount={stepCount}
      onPair={() => setPaired(true)}
      onDone={onFinish}
    />
  );
}

Object.assign(window, { OnboardingFlow });
