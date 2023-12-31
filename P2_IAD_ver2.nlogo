breed [buyers buyer]
breed [sellers seller]

buyers-own [
  budget
  ticket
  scene
  state
  received_protocol
]

sellers-own [
  cryptocurrencies
  tax_percent
  received_protocol
]

;constantes para definir estados, protocolos y tipo de contenido
globals [
  INIT_STATE
  WAITING_RESPONSE
  END_STATE

  REQUEST
  INFORM
  CONFIRM
  DENY

  SHOW_REMAINING_COINS
  BUY_COIN
  INFORM_TAX_ADDITION
  ALL_COIN_SOLD_OUT
]

turtles-own [
  current-ticket
]

to setup
  clear-all
  gloval_constant_var_setup
  sellers_setup
  buyers_setup
  reset-ticks
end

to gloval_constant_var_setup
  set INIT_STATE 0
  set WAITING_RESPONSE 1
  set END_STATE 2

  set REQUEST 0
  set INFORM 1
  set CONFIRM 2
  set DENY 3

  set SHOW_REMAINING_COINS 0
  set BUY_COIN 1
  set INFORM_TAX_ADDITION 2
  set ALL_COIN_SOLD_OUT 4
end

to sellers_setup
  create-sellers sellers_num
  [
    setxy random-xcor random-ycor
    set shape "house"
    set cryptocurrencies n-values 3 [random 24 + 1]
    set tax_percent tax_value / 100
    set received_protocol []
  ]
end

to buyers_setup
  create-buyers buyers_num
  [
    setxy random-xcor random-ycor
    set shape "person"
    set budget random 491 + 10
    set ticket [0 0 0]
    set scene 1
    set state INIT_STATE
    set received_protocol []
  ]
end

; start main flow

to go
  ask buyers
  [
    (ifelse
      scene = 1 [watchPriceCoin]
      scene = 2 [buyCoin]
    )
  ]
  ask sellers
  [
    show cryptocurrencies
    respond_request
    check_end
  ]
  tick
  wait 0.1
end

;buyer function

to watchPriceCoin
  set ticket replace-item 0 ticket (random 401 + 100)
  set ticket replace-item 1 ticket (random 191 + 10)
  set ticket replace-item 2 ticket (random 91 + 30)

  show (word budget ticket )
  set scene 2
  set state INIT_STATE
end

;depende del estado hace una acción o la otra
to buyCoin
  (ifelse
    state = INIT_STATE
      [ request_to_show_coins ]
    state = WAITING_RESPONSE
      [ receive_sellers_response ]
      [ die ]
  )
end

;pide a todos los sellers que le enseñe los coins que tiene y
;cambia su estado a estado de espera de respuesta
;si con su ticket no puede comprar nada entonces no hace nada y
;cambia su estado a estado final
to request_to_show_coins
  ifelse current-ticket != nobody
  [
    ifelse (check_budget = 1)
    [
      let buyerx who
      let content ticket
      ask sellers
      [
        let sellery who
        sendProtocol REQUEST buyerx sellery SHOW_REMAINING_COINS content
      ]
      set state WAITING_RESPONSE
    ]
    [
      show "No tengo dinero suficiente para comprar coins"
      set state END_STATE
    ]
  ]
  [
    show "No tienes un ticket válido para comprar."
    set state END_STATE
  ]
end

;comprueba si su ticket es válido o no
;si es valido devuelve 1 y si no devuelve 0
to-report check_budget
  ifelse (budget > item 0 ticket or
      budget > item 1 ticket or
      budget > item 2 ticket)
  [ report 1 ]
  [ report 0 ]
end

;recive la respuesta del seller
;solo coge la primera respuesta que le ha llegado para no hacer multiples transacciones.
;cuando le llega la lista de los coins del seller busca el máximo coin que puede comprar y
;pide al seller para comprar ese coin
;cuando le llega la información de la taxa comprueba de nuevo si se puede comprar,
;si se puede comprar confirma la compra y espera la última confirmación.
;si llega la confirmación de comprar coin entonces se lo queda y cambia el estado en fin
;en cualquier momento si le llega el protocolo de DENY se cambia el estado en fin
to receive_sellers_response
  if not empty? received_protocol
  [
    let message item 0 received_protocol
    show message
    let protocol item 0 message
    let sender item 1 message
    let receiver item 2 message
    let content_type item 3 message
    let content item 4 message
    if protocol = INFORM
    [
      if content_type = SHOW_REMAINING_COINS
      [
        let buy_coin_index get_most_expensive_coin content
        sendProtocol REQUEST who sender BUY_COIN buy_coin_index
      ]
      if content_type = INFORM_TAX_ADDITION
      [
        apply_tax_to_ticket content
        let buy_coin_index get_most_expensive_coin [1 1 1]
        ifelse buy_coin_index = -1
        [
          show "falta dinero para comprar el coin"
          set state END_STATE
        ]
        [ sendProtocol CONFIRM who sender BUY_COIN buy_coin_index ]
      ]
    ]
    if protocol = CONFIRM
    [
      if content_type = BUY_COIN
      [
        show "He comprado un coin"
        set state END_STATE
      ]
    ]
    if protocol = DENY
    [
      show "No he podido comprar ningún coin"
      set state END_STATE
    ]
    set received_protocol []
  ]
end

;devuelve el index del coin más caro que puede comprar
;si existe algún coin que puede comprar devuelve su index
;si no, devuelve -1
;[Bitcoin, Dogecoin, USDcoin]
to-report get_most_expensive_coin [ remaining_coins ]
  let Bitcoin item 0 remaining_coins
  let Dogecoin item 1 remaining_coins
  let USDcoin item 2 remaining_coins

  if Bitcoin = 0 or budget < Bitcoin
  [ set ticket replace-item 0 ticket 0 ]
  if Dogecoin = 0 or budget < Dogecoin
  [ set ticket replace-item 1 ticket 0 ]
  if USDcoin = 0 or budget < USDcoin
  [ set ticket replace-item 2 ticket 0 ]

  let max_value max ticket
  ifelse max_value = 0
  [report -1]
  [
    let max_index position max_value ticket
    report max_index
  ]
end

;aplica la taxa a los valores del ticket
to apply_tax_to_ticket [ tax ]
  let Bitcoin item 0 ticket
  let Dogecoin item 1 ticket
  let USDcoin item 2 ticket

  set Bitcoin Bitcoin + Bitcoin * tax
  set Dogecoin Dogecoin + Dogecoin * tax
  set USDcoin USDcoin + USDcoin * tax

  set ticket replace-item 0 ticket Bitcoin
  set ticket replace-item 1 ticket Dogecoin
  set ticket replace-item 2 ticket USDcoin
end

; seller function

;responde a los requests del buyer
;en caso de que recive request de SHOW_REMAINING_COINS devuelve el mensage con
;la lista de criptomonedas que tiene
;en caso de que recive request de INFORM_TAX_ADDITION devuelve el mensage con
;la taxa de ahora
;en caso de que recive CONFIRM de BUY_COIN comprueba por último si tiene coins suficientes
;y si lo tiene entonces confirma la compra.
;sino, envia el protocolo de deny.
;en cualquier momento si no le queda ningún coin [0, 0, 0] envia DENY en cualquier estado.
to respond_request
  if not empty? received_protocol
  [
    foreach received_protocol [ [message] ->
      show message
      let protocol item 0 message
      let sender item 1 message
      let receiver item 2 message
      let content_type item 3 message
      let content item 4 message
      (ifelse
        max cryptocurrencies = 0 ; check if all coins is sold out
        [ show "no hay mas coins a vender"
          sendProtocol DENY who sender ALL_COIN_SOLD_OUT cryptocurrencies ]
        protocol = REQUEST
        [
          if content_type = SHOW_REMAINING_COINS
          [ sendProtocol INFORM who sender SHOW_REMAINING_COINS cryptocurrencies ]
          if content_type = BUY_COIN
          [ sendProtocol INFORM who sender INFORM_TAX_ADDITION tax_percent ]
        ]
        protocol = CONFIRM
        [
          if content_type = BUY_COIN
          [
            let coin_index content
            show (word "coin" coin_index)
            let coin item coin_index cryptocurrencies
            ifelse
            coin = 0
            [ sendProtocol DENY who sender ALL_COIN_SOLD_OUT cryptocurrencies ]
            [
              set cryptocurrencies replace-item coin_index cryptocurrencies (coin - 1)
              sendProtocol CONFIRM who sender BUY_COIN coin_index
              show (word "Coins que falta" cryptocurrencies)
            ]
          ]
        ]
      )

    ]
    set received_protocol []
  ]
end

;comprueba si le queda criptomonedas para vender.
;si no hay mas para vender entonces se elimina
to check_end
  if max cryptocurrencies = 0
  [
    show "No hay mas coins para vender"
    die
  ]
end

; gloval function

;función para transmitir protocolos entre los buyers y sellers
;dado los elementos pasado por parámetro de la función
;crea una lista que junta todos los elementos y añade al finál de la lista de
;received_protocol de receiver
to sendProtocol [ protocol sender receiver content_type content ]
  let message (list protocol sender receiver content_type content)
  ask turtles with [who = receiver]
  [ set received_protocol lput message received_protocol ]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
703
504
-1
-1
14.7
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
27
47
96
80
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
114
48
183
81
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
20
98
192
131
sellers_num
sellers_num
1
20
1.0
1
1
NIL
HORIZONTAL

SLIDER
20
138
192
171
buyers_num
buyers_num
0
200
172.0
1
1
NIL
HORIZONTAL

SLIDER
20
178
192
211
tax_value
tax_value
0
100
10.0
1
1
%
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This model simulates a market where buyers and sellers engage in transactions involving cryptocurrencies. The buyers have a budget and tickets to be able to buy different types of cryptocurrencies. Sellers have a certain amount of cryptocurrencies and respond to buyers requests. The model shows a market interaction flow, including the exchange of protocols and confirmation of transactions.

## HOW IT WORKS

**Buyers and Sellers Setup:** The model starts by creating two breeds, buyers and sellers. Each buyer and seller has specific attributes
Buyer attributes: budget, ticket, scene, state, received_protocol
Seller attributes: cryptocurrencies, tax_percent, received_protocol

**Global Constants Setup:** Various constants are defined globally, representing states, protocols, and content types used in the simulation.

**Main flow (go):** In each iteration, buyers watch cryptocurrency prices or attempt to buy coins based on their current scene and state. Sellers respond to requests, show their cryptocurrencies, and check for the end condition. The simulation progresses in discrete time steps.

**Buyer Functions:** Buyers generate random ticket with the values of the cryptocurrencies, request sellers to show their available coins, and handle responses to initiate or confirm purchases.

**Seller Functions:** Sellers try to responde to the buyers sequests, show available cryptocurrencies, and handle confirmation or denial of coin purchases. Sellers check for the end condition when no more coins are available.

**Send Protocol:** This function facilitates communication between buyers and sellers by transmitting protocols and relevant info.


## HOW TO USE IT

We created 5 components:

**Setup:** press the setup button to initialize the simulation with buyers and sellers

**Go:** press the go button to run the simulation, allowing buyers and sellers to intract and conduct transactions.

**Sellers_num:** this slider is responsible for create the sellers of the market.

**Buyers_num:** this slider is responsible for create the buyers of the market.

**Tax_value:** this slider is responsible for setting the tax when making a sale.

## THINGS TO NOTICE

Observe how buyers generate random ticket values and attempt to purchase cryptocurrencies based on their budget.
Sellers respond to buyer requests, show available cryptocurrencies, and confirm or deny transactions.
The simulation progresses through different scenes and states, imitating a basic market interaction and using a protocol.

## THINGS TO TRY

Experiment with different initial parameters such as the number of buyers (buyers_num), sellers (sellers_num) and tax (tax_value). Observe how the market dynamics change as you adjust the budget of buyers or the initial amount of cryptocurrencies held by sellers.

## EXTENDING THE MODEL

- Implement more sophisticated buyer and seller strategies.
- Introduce additional cryptocurrency types or modify existing ones.
- Incorporate market dynamics such as price fluctuations, supply and demand factors, etc.
- Modify the protocol for obtain a longer conversation between sellers and buyers.

## NETLOGO FEATURES

**Breeds:** The model uses NetLogo breeds to differentiate between buyers and sellers.

**Global Variables:** Various global variables are used to define constants and states.

**Turtles-own and Sellers-own:** Turtles (buyers and sellers) have their own set of attributes that influence their behavior.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
