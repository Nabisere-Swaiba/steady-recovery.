// Supabase Edge Function "notify": emails the admin when a doctor registers,
// and emails the doctor when the admin approves or rejects them (FR3).
// Secrets needed: BREVO_API_KEY, SENDER_EMAIL, ADMIN_EMAIL
Deno.serve(async (req) => {
  const body = await req.json();
  const rec = body.record;
  const old = body.old_record;
  let to: string | null = null;
  let subject = "";
  let html = "";

  if (body.type === "INSERT" && rec?.role === "DOCTOR") {
    to = Deno.env.get("ADMIN_EMAIL") ?? null;
    subject = "New doctor awaiting verification - SteadyRecovery";
    html = `<p><b>${rec.full_name}</b> (${rec.email}) registered as a doctor and is <b>PENDING</b> verification.</p>
            <p>Open the SteadyRecovery admin screen to approve or reject the application.</p>`;
  } else if (
    body.type === "UPDATE" && rec?.role === "DOCTOR" &&
    old?.verification_status !== rec.verification_status &&
    ["APPROVED", "REJECTED"].includes(rec.verification_status)
  ) {
    to = rec.email;
    const ok = rec.verification_status === "APPROVED";
    subject = ok ? "Your SteadyRecovery account is approved" : "Your SteadyRecovery application";
    html = ok
      ? `<p>Hello ${rec.full_name}, your credentials were verified. Open the app and tap <b>Check status</b> to start using the clinical tools.</p>`
      : `<p>Hello ${rec.full_name}, your application could not be approved at this time. Please contact the platform administrator.</p>`;
  }

  if (!to) return new Response("skipped");

  const r = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: { "api-key": Deno.env.get("BREVO_API_KEY")!, "content-type": "application/json" },
    body: JSON.stringify({
      sender: { name: "SteadyRecovery", email: Deno.env.get("SENDER_EMAIL") },
      to: [{ email: to }],
      subject,
      htmlContent: html,
    }),
  });
  return new Response(await r.text(), { status: r.status });
});
