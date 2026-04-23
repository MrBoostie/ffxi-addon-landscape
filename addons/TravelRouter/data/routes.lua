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
  },

  sandoria = {
    candidates = {
      {
        name = 'home-point',
        score = 15,
        requires = {'hp'},
        steps = {
          'say:Warp to Southern San d\'Oria via Home Point',
          'cmd:hp San d\'Oria',
          'say:Arrived in San d\'Oria'
        }
      },
      {
        name = 'warp-fallback',
        score = 8,
        requires = {'warp'},
        steps = {
          'cmd:warp sandoria',
          'say:Arrived in San d\'Oria'
        }
      }
    }
  },

  bastok = {
    candidates = {
      {
        name = 'home-point',
        score = 15,
        requires = {'hp'},
        steps = {
          'say:Warp to Bastok Markets via Home Point',
          'cmd:hp Bastok',
          'say:Arrived in Bastok'
        }
      },
      {
        name = 'warp-fallback',
        score = 8,
        requires = {'warp'},
        steps = {
          'cmd:warp bastok',
          'say:Arrived in Bastok'
        }
      }
    }
  },

  windurst = {
    candidates = {
      {
        name = 'home-point',
        score = 15,
        requires = {'hp'},
        steps = {
          'say:Warp to Windurst Woods via Home Point',
          'cmd:hp Windurst',
          'say:Arrived in Windurst'
        }
      },
      {
        name = 'warp-fallback',
        score = 8,
        requires = {'warp'},
        steps = {
          'cmd:warp windurst',
          'say:Arrived in Windurst'
        }
      }
    }
  },

  selbina = {
    candidates = {
      {
        name = 'survival-guide',
        score = 14,
        requires = {'sg'},
        steps = {
          'cmd:sg Selbina',
          'say:Arrived in Selbina'
        }
      },
      {
        name = 'warp-fallback',
        score = 7,
        requires = {'warp'},
        steps = {
          'cmd:warp selbina',
          'say:Arrived in Selbina'
        }
      }
    }
  },

  mhaura = {
    candidates = {
      {
        name = 'survival-guide',
        score = 14,
        requires = {'sg'},
        steps = {
          'cmd:sg Mhaura',
          'say:Arrived in Mhaura'
        }
      },
      {
        name = 'warp-fallback',
        score = 7,
        requires = {'warp'},
        steps = {
          'cmd:warp mhaura',
          'say:Arrived in Mhaura'
        }
      }
    }
  },

  kazham = {
    candidates = {
      {
        name = 'survival-guide',
        score = 14,
        requires = {'sg'},
        steps = {
          'cmd:sg Kazham',
          'say:Arrived in Kazham'
        }
      },
      {
        name = 'warp-fallback',
        score = 7,
        requires = {'warp'},
        steps = {
          'cmd:warp kazham',
          'say:Arrived in Kazham'
        }
      }
    }
  },

  rabao = {
    candidates = {
      {
        name = 'survival-guide',
        score = 14,
        requires = {'sg'},
        steps = {
          'cmd:sg Rabao',
          'say:Arrived in Rabao'
        }
      },
      {
        name = 'warp-fallback',
        score = 7,
        requires = {'warp'},
        steps = {
          'cmd:warp rabao',
          'say:Arrived in Rabao'
        }
      }
    }
  },

  aht_urhgan = {
    candidates = {
      {
        name = 'home-point',
        score = 15,
        requires = {'hp'},
        steps = {
          'say:Warp to Aht Urhgan Whitegate via Home Point',
          'cmd:hp Aht Urhgan Whitegate',
          'say:Arrived in Whitegate'
        }
      },
      {
        name = 'warp-fallback',
        score = 8,
        requires = {'warp'},
        steps = {
          'cmd:warp whitegate',
          'say:Arrived in Whitegate'
        }
      }
    }
  },

  nashmau = {
    candidates = {
      {
        name = 'survival-guide',
        score = 13,
        requires = {'sg'},
        steps = {
          'cmd:sg Nashmau',
          'say:Arrived in Nashmau'
        }
      }
    }
  },

  tavnazia = {
    candidates = {
      {
        name = 'home-point',
        score = 15,
        requires = {'hp'},
        steps = {
          'cmd:hp Tavnazian Safehold',
          'say:Arrived in Tavnazian Safehold'
        }
      },
      {
        name = 'warp-fallback',
        score = 7,
        requires = {'warp'},
        steps = {
          'cmd:warp tavnazia',
          'say:Arrived in Tavnazian Safehold'
        }
      }
    }
  },

  escha_zitah = {
    candidates = {
      {
        name = 'home-point',
        score = 14,
        requires = {'hp'},
        steps = {
          'cmd:hp Escha - Zi\'Tah',
          'say:Arrived in Escha Zi\'Tah'
        }
      }
    }
  },

  escha_ruaun = {
    candidates = {
      {
        name = 'home-point',
        score = 14,
        requires = {'hp'},
        steps = {
          'cmd:hp Escha - Ru\'Aun',
          'say:Arrived in Escha Ru\'Aun'
        }
      }
    }
  },

  reisenjima = {
    candidates = {
      {
        name = 'home-point',
        score = 14,
        requires = {'hp'},
        steps = {
          'cmd:hp Reisenjima',
          'say:Arrived in Reisenjima'
        }
      }
    }
  },

  abyssea_la_theine = {
    candidates = {
      {
        name = 'waypoint',
        score = 12,
        requires = {'warp'},
        steps = {
          'cmd:warp abyssea_la_theine',
          'say:Arrived in Abyssea - La Theine'
        }
      }
    }
  },

  dynamis_san_doria = {
    candidates = {
      {
        name = 'warp-entry',
        score = 10,
        requires = {'warp'},
        steps = {
          'say:Travel to San d\'Oria first, then enter Dynamis',
          'cmd:warp sandoria',
          'wait:3',
          'say:Proceed to Trail Markings for Dynamis entry'
        }
      }
    }
  },
}
