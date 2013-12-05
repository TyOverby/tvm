library math #

:factorial # n passed in on r1
  set r2 r1
  :factloop
    ife r1 1
      set pc math.factend

    uisub r1 1
    uimul r2 r1
    set pc math.factloop

  :factend
    set r1 r2
    ret

:fibonacci
  # r1: n
  # r2: x
  # r3: y
  # r4: z
  set r2 0
  set r3 1
  :fibloop
    ife r1 0
      set pc math.fibend

    set r4 r2  # z = x + y
    uiadd r4 r3

    set r2 r3  # x = y
    set r3 r4  # y = z

    uisub r1 1
    set pc math.fibloop
  :fibend
    set r1 r2
    ret


:main
  set r1 10
  jump math.fibonacci #math.factorial
  sys 0
  sys 2
