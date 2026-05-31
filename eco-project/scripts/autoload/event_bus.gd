extends Node

## Центральная шина событий для коммуникации между слоями.
## Все сигналы определяются здесь. Сцены подписываются на EventBus.

## Запускается когда игра стартует
signal game_started

## Запускается когда игра на паузе
signal game_paused

## Запускается когда игра возобновлена
signal game_resumed

## Запускается когда игра завершена
signal game_ended(reason: String)

## Запускается когда игрок получает урон
signal player_damaged(amount: int)

## Запускается когда игрок умирает
signal player_died(reason: String)

## Запускается когда экосистема меняется
signal ecosystem_changed(new_state: Resource)

## Запускается когда сохранение выполнено
signal game_saved(slot: int)

## Запускается когда загрузка выполнена
signal game_loaded(slot: int)