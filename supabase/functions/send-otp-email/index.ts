import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { SmtpClient } from "https://deno.land/x/smtp@v0.7.0/mod.ts";

const SMTP_HOST = "mail.privateemail.com";
const SMTP_PORT = 465;
const SMTP_USER = Deno.env.get("SMTP_USER") || "info@h-bot.tech";
const SMTP_PASS = Deno.env.get("SMTP_PASS") || "";
const FROM_NAME = "H-Bot Smart Home";
const FROM_EMAIL = "info@h-bot.tech";

// Shared secret to authenticate requests from our app
const API_SECRET = Deno.env.get("OTP_API_SECRET") || "";

function generateOtpHtml(otp: string, type: "signup" | "reset"): string {
  const title = type === "signup" ? "Verify Your Email" : "Reset Your Password";
  const message =
    type === "signup"
      ? "Welcome to H-Bot Smart Home! Use the code below to verify your email address."
      : "We received a request to reset your password. Use the code below to continue.";
  const footer =
    type === "signup"
      ? "If you didn't create an H-Bot account, you can safely ignore this email."
      : "If you didn't request a password reset, you can safely ignore this email.";

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
</head>
<body style="margin:0;padding:0;background-color:#010510;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background-color:#010510;">
    <tr>
      <td align="center" style="padding:40px 20px;">
        <table role="presentation" cellpadding="0" cellspacing="0" width="480" style="max-width:480px;width:100%;">
          
          <!-- Logo -->
          <tr>
            <td align="center" style="padding-bottom:32px;">
              <div style="width:64px;height:64px;border-radius:16px;background:linear-gradient(135deg,#0A1628,#0883FD);display:inline-block;line-height:64px;text-align:center;">
                <span style="font-size:32px;">🏠</span>
              </div>
              <div style="margin-top:12px;font-size:20px;font-weight:700;color:#FFFFFF;letter-spacing:0.5px;">H-Bot</div>
            </td>
          </tr>

          <!-- Card -->
          <tr>
            <td style="background-color:#1A202B;border-radius:16px;padding:40px 32px;">
              
              <!-- Title -->
              <h1 style="margin:0 0 8px;font-size:24px;font-weight:700;color:#FFFFFF;text-align:center;">
                ${title}
              </h1>
              
              <!-- Message -->
              <p style="margin:0 0 32px;font-size:15px;line-height:1.6;color:#C7C9CC;text-align:center;">
                ${message}
              </p>
              
              <!-- OTP Code -->
              <div style="background-color:#010510;border:1px solid #181B1F;border-radius:12px;padding:24px;text-align:center;margin-bottom:32px;">
                <div style="font-size:36px;font-weight:700;letter-spacing:12px;color:#0883FD;font-family:'Courier New',monospace;">
                  ${otp}
                </div>
                <div style="margin-top:8px;font-size:13px;color:#7A8494;">
                  Code expires in 10 minutes
                </div>
              </div>
              
              <!-- Warning -->
              <p style="margin:0;font-size:13px;line-height:1.5;color:#7A8494;text-align:center;">
                ${footer}
              </p>
              
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding-top:24px;text-align:center;">
              <p style="margin:0;font-size:12px;color:#7A8494;">
                © 2026 H-Bot Smart Home · <a href="https://h-bot.tech" style="color:#0883FD;text-decoration:none;">h-bot.tech</a>
              </p>
              <p style="margin:8px 0 0;font-size:11px;color:#555;">
                This is an automated message. Please do not reply.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

function generatePlainText(otp: string, type: "signup" | "reset"): string {
  const title = type === "signup" ? "Verify Your Email" : "Reset Your Password";
  const msg =
    type === "signup"
      ? "Welcome to H-Bot Smart Home! Use this code to verify your email:"
      : "Use this code to reset your password:";
  return `${title}\n\n${msg}\n\n${otp}\n\nThis code expires in 10 minutes.\n\n© 2026 H-Bot Smart Home · h-bot.tech`;
}

serve(async (req: Request) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST,OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type,Authorization,x-api-secret",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
  }

  try {
    // Verify API secret
    const secret = req.headers.get("x-api-secret");
    if (!API_SECRET || secret !== API_SECRET) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }

    const { email, otp, type } = await req.json();

    if (!email || !otp || !type) {
      return new Response(JSON.stringify({ error: "Missing email, otp, or type" }), { status: 400 });
    }

    if (!["signup", "reset"].includes(type)) {
      return new Response(JSON.stringify({ error: "Invalid type" }), { status: 400 });
    }

    const subject =
      type === "signup"
        ? `${otp} is your H-Bot verification code`
        : `${otp} is your H-Bot password reset code`;

    const client = new SmtpClient();

    await client.connectTLS({
      hostname: SMTP_HOST,
      port: SMTP_PORT,
      username: SMTP_USER,
      password: SMTP_PASS,
    });

    await client.send({
      from: `${FROM_NAME} <${FROM_EMAIL}>`,
      to: email,
      subject,
      content: generatePlainText(otp, type),
      html: generateOtpHtml(otp, type),
    });

    await client.close();

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  } catch (error) {
    console.error("Email send error:", error);
    return new Response(JSON.stringify({ error: "Failed to send email", details: String(error) }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});
