
(() => {
  "use strict";

  // =====================================
  // 1. Create the chat interface
  // =====================================

  const widget = document.createElement("div");
  widget.id = "cloudmart-ai-widget";

  widget.innerHTML = `
    <button
      id="cm-chat-toggle"
      type="button"
      aria-expanded="false"
      aria-controls="cm-chat-panel"
    >
      AI Shopping Assistant
    </button>

    <section
      id="cm-chat-panel"
      aria-label="CloudMart AI Assistant"
      hidden
    >
      <div class="cm-chat-header">
        <strong>CloudMart Assistant</strong>
        <button
          id="cm-chat-close"
          type="button"
          aria-label="Close chat"
        >×</button>
      </div>

      <div
        id="cm-chat-messages"
        role="log"
        aria-live="polite"
        aria-relevant="additions"
      ></div>

      <form id="cm-chat-form">
        <label for="cm-chat-input">
          Ask about products, orders or policies
        </label>

        <div class="cm-chat-form-row">
          <input
            id="cm-chat-input"
            type="text"
            placeholder="Type your question..."
            maxlength="2000"
            autocomplete="off"
            required
          />

          <button
            id="cm-chat-send"
            type="submit"
          >Send</button>
        </div>
      </form>

      <p class="cm-chat-note">
        Demo assistant. Each question is handled
        independently. Do not enter personal data.
      </p>
    </section>
  `;

  document.body.appendChild(widget);

  const toggle = document.getElementById("cm-chat-toggle");
  const close = document.getElementById("cm-chat-close");
  const panel = document.getElementById("cm-chat-panel");
  const messages = document.getElementById("cm-chat-messages");
  const form = document.getElementById("cm-chat-form");
  const input = document.getElementById("cm-chat-input");
  const sendButton = document.getElementById("cm-chat-send");

  // =====================================
  // 2. Open and close the chat
  // =====================================

  function setOpen(open) {
    panel.hidden = !open;
    toggle.setAttribute("aria-expanded", String(open));

    if (open) {
      input.focus();
    } else {
      toggle.focus();
    }
  }

  toggle.addEventListener("click", () => {
    setOpen(panel.hidden);
  });

  close.addEventListener("click", () => {
    setOpen(false);
  });

  // =====================================
  // 3. Display a message safely
  // =====================================

  function addMessage(type, text) {
    const message = document.createElement("div");

    message.className = `cm-chat-message cm-chat-${type}`;

    // Never interpret LLM output as HTML.
    message.textContent = text;

    messages.appendChild(message);

    messages.scrollTop = messages.scrollHeight;
  }

  addMessage(
    "assistant",
    "Hello! I can help with CloudMart products, " +
    "shipping, returns and demo order questions."
  );

  // =====================================
  // 4. Handle the customer question
  // =====================================

  form.addEventListener("submit", async (event) => {
    event.preventDefault();

    const prompt = input.value.trim();

    if (!prompt || sendButton.disabled) {
      return;
    }

    if (prompt.length > 2000) {
      addMessage("error", "The question is too long.");
      return;
    }

    addMessage("user", prompt);

    input.value = "";
    input.disabled = true;
    sendButton.disabled = true;
    sendButton.textContent = "Thinking...";

    const controller = new AbortController();

    const timeout = setTimeout(() => {
      controller.abort();
    }, 190000);

    try {
      // =================================
      // 5. Call the frontend reverse proxy
      // =================================

      const response = await fetch("/assistant/chat", {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          prompt: prompt
        }),
        signal: controller.signal
      });

      if (response.status === 403) {
        throw new Error(
          "Chat access is restricted for this demo."
        );
      }

      if (response.status === 429) {
        throw new Error(
          "Too many requests. Please try again later."
        );
      }

      if (!response.ok) {
        throw new Error(
          "The assistant service is unavailable."
        );
      }

      // =================================
      // 6. Read the agent's JSON response
      // =================================

      const result = await response.json();

      if (
        result.success === true &&
        typeof result.answer === "string"
      ) {
        addMessage("assistant", result.answer);

        if (
          Array.isArray(result.retrieved_sources) &&
          result.retrieved_sources.length > 0
        ) {
          addMessage(
            "source",
            "Retrieved sources: " +
            result.retrieved_sources.join(", ")
          );
        }
      } else {
        addMessage(
          "error",
          typeof result.answer === "string"
            ? result.answer
            : "I could not complete that request."
        );
      }

    } catch (error) {
      const message =
        error.name === "AbortError"
          ? "The request timed out."
          : error.message;

      addMessage("error", message);

    } finally {
      clearTimeout(timeout);

      input.disabled = false;
      sendButton.disabled = false;
      sendButton.textContent = "Send";

      if (!panel.hidden) {
        input.focus();
      }
    }
  });
})();
