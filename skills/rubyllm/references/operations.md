# Models and operations

Read this for media, embeddings, reranking, judgments, and evaluations.

- Use individual operations directly for media, document processing, moderation, embeddings, and reranking. Read their typed results and use `save` on generated images, video, and speech. Check each operation's provider, model, and credentials; a configured chat provider may not offer every operation. `animate` waits for completion; use `animate_later` when the application needs to manage the job. To try another image model when one is rate limited or overloaded, pass `fallbacks:` to `paint` rather than rescuing and retrying by hand (2.2).
- For a yes/no probability, a choice, or a score about application data, subclass `RubyLLM::Judge` and call `.judge(input)` instead of parsing free text from a chat (2.1). Backends are TypeSafe's Jev, OpenAI Decisions, and local decision models such as Clef with `provider: :ollama`.

Specs check code; evaluations check how often the model gets the answer right (2.1). Generate one with `bin/rails generate ruby_llm:evaluation Support`, then read `evaluations/`. Model grading costs money on every run, so keep graded evaluations out of the default test run.
