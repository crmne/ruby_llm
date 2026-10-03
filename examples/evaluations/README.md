# Evaluation examples

Run the offline tool-selection evaluation from the repository root:

```sh
bundle exec ruby -Ilib examples/evaluations/run.rb
```

It contains one correct request, one incorrect tool, and one incorrect order ID. The expected report is one pass and two failures. No tools execute and no API requests are made.

To assess the answer dataset, configure your provider key and choose a registered model:

```sh
EVAL_MODEL="$YOUR_EVALUATOR_MODEL" bundle exec ruby -Ilib examples/evaluations/run.rb
```

Reports are written to `examples/evaluations/tmp`. The answer dataset has four correct answers and four incorrect answers, including a paraphrase, an incorrect number, and a grading-injection attempt. The expected verdicts for cases 01 through 08 are pass, pass, fail, pass, fail, pass, fail, fail. These labels are deliberately absent from the evidence sent to the evaluator.

For native decision probabilities, select a registered judgment model and add an explicit `minimum:` to the criterion to turn measurements into passes or failures. Calibrate that threshold on separate labeled examples.

`spec/ruby_llm/evaluation_live_spec.rb` exercises the answer dataset with a default reviewer, a custom Agent, and a compatible decision endpoint. It also exercises an evaluator that reads a synthetic policy through a tool. The specs record provider traffic through the repository's VCR setup.
