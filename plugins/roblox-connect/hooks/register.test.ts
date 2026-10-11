import { test, expect } from 'claude-code/testing'

const CHECK = 'mcp__robloxstudio-mcp__get_connected_instances'

for (const [name, answer, shown] of [
  ['shows connected when Studio is open', '[{"instanceId":"a","placeName":"Obby"}]', 'Roblox Studio: connected'],
  ['shows not connected when no Studio is open', '[]', 'Roblox Studio: not connected (open a place, then /studio)'],
] as const) {
  test(name, async ($, on) => {
    const statuses: (string | undefined)[] = []
    on('ui.status', ($, e) => {
      statuses.push(e.text)
      return { value: undefined }
    })
    on('ui.toast', () => ({ value: undefined }))
    on('tool.call', { tool: CHECK }, () => ({ result: [{ type: 'text', text: answer }] }) as never)

    await $.tool.call({ tool: CHECK, input: {} } as never)

    expect(statuses.at(-1)).toBe(shown)
  })
}
