# TDD lite

Lightweight TDD discipline for when the `tdd` skill is not installed.

## Workflow

1. **Tracer bullet**: pick the first acceptance criterion. Write ONE test that proves the path works end-to-end. Make it fail (RED), then write the minimal code to pass (GREEN). This proves your approach before committing to it.
2. **Loop**: for each remaining acceptance criterion — one at a time, never write all tests first:
   - **RED**: write a test for this criterion. It must fail.
   - **GREEN**: write the minimal code to pass. No more.
   - Run the **full project test suite** (not just your new test). Must be green.
3. **Refactor**: after all acceptance criteria pass, look for refactor opportunities (extract duplication, simplify interfaces). Run full suite after each step. Never refactor while red.

## Per-cycle checklist

- Test describes behavior, not implementation
- Test uses public interface only
- Test would survive an internal refactor
- Code is minimal for this test
- No speculative features added
