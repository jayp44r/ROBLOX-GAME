import type { Register } from 'claude-code'

const STUDIO = 'mcp__robloxstudio-mcp__'
const CHECK = `${STUDIO}get_connected_instances`

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'studio',
      description: 'Connect to Roblox Studio',
    })
    $.ui.status('Roblox Studio: not checked yet (type /studio)')

    return next(e)
  })

  on('command.run', { command: 'studio' }, async $ => {
    $.ui.status('Roblox Studio: connecting...')
    await $.prompt.submit({
      text: 'Connect to Roblox Studio now, following the steps in CLAUDE.md. Reply in one line.',
    })

    return { text: 'Connecting to Roblox Studio...' }
  })

  on('tool.call', async ($, e, next) => {
    if (!e.tool.startsWith(STUDIO)) return next(e)

    const ran = await next(e)
    if (ran.deny !== undefined) return ran

    if (ran.isError === true) {
      $.ui.status('Roblox Studio: not connected (type /studio)')
    } else if (e.tool === CHECK) {
      const found = JSON.stringify(ran.result ?? '').includes('instanceId')
      $.ui.status(found ? 'Roblox Studio: connected' : 'Roblox Studio: not connected (open a place, then /studio)')
      if (found) $.ui.toast('Connected to Roblox Studio')
    } else {
      $.ui.status('Roblox Studio: connected')
    }

    return ran
  }).catch(($, e, next) => next(e))
}
