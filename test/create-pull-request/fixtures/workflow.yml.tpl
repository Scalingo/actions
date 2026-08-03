name: E2E test create-pull-request action

on:
  workflow_dispatch:
    inputs:
      payload:
        description: "Arbitrary content written to CHANGED.md, forces a real diff"
        required: true

permissions:
  contents: write
  pull-requests: write

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Make a change
        run: |
          mkdir -p generated
          printf '%s\n' "${{ github.event.inputs.payload }}" > generated/CHANGED.md

      - name: Create Pull Request
        id: cpr
        uses: __CPR_ACTION_REF__
        with:
          commit-message: "__CPR_COMMIT_MESSAGE__"
          title: "__CPR_TITLE__"
          body: "__CPR_BODY__"
          branch: "__CPR_BRANCH__"

      - name: Print action outputs
        run: |
          echo "pull-request-number=${{ steps.cpr.outputs.pull-request-number }}"
          echo "pull-request-url=${{ steps.cpr.outputs.pull-request-url }}"
          echo "pull-request-operation=${{ steps.cpr.outputs.pull-request-operation }}"
