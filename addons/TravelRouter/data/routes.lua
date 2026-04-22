return {
  jeuno = {
    candidates = {
      {
        name = 'home-point-direct',
        score = 15,
        requires = {'hp'},
        steps = {
          'say:Use Home Point warp to Ru\'Lude Gardens',
          'cmd:hp #1',
          'say:Move to your Jeuno objective from HP'
        }
      },
      {
        name = 'warp-fallback',
        score = 8,
        requires = {'warp'},
        steps = {
          'say:Using fallback warp helper route to Jeuno',
          'cmd:warp jeuno',
          'say:Proceed to objective'
        }
      }
    }
  },

  adoulin = {
    candidates = {
      {
        name = 'survival-guide-direct',
        score = 15,
        requires = {'sg'},
        steps = {
          'say:Open Survival Guide and select Western Adoulin',
          'cmd:sg Western Adoulin',
          'say:Move to waypoint/NPC for your task'
        }
      },
      {
        name = 'warp-fallback',
        score = 7,
        requires = {'warp'},
        steps = {
          'say:Fallback route via warp command',
          'cmd:warp adoulin',
          'say:Continue to objective'
        }
      }
    }
  },

  norg = {
    candidates = {
      {
        name = 'warp-direct',
        score = 12,
        requires = {'warp'},
        steps = {
          'say:Route toward Norg via trusted teleport path',
          'cmd:warp norg',
          'say:Enter Norg and proceed'
        }
      }
    }
  }
}
