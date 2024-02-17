# Twitch Rewards App

Простий застосунок для маніпулювання налаштуваннями OBS використовуючи бали каналу.

## Базове налаштування

1. Завантажте актуальний білд застосунку (.zip архів) тут [Releases](https://github.com/dealnotedev/twitch_rewards_app/releases).
2. Розпакуйте архів в зручне для вас місце на диску і запустіть twitch_listener.exe.
![plot](./images/login.jpg =250x)
3. Авторизуйтесь на Twitch, ознайомившись з правами, які ви надасте застосунку.
![plot](./images/browser_permissions.jpg)
4. Після успішної авторизації в браузері ви маєте побачити наступне.
![plot](./images/browser_logged.jpg)
5. А в застосунку - наступне.
![plot](./images/main_empty.jpg)
6. Для взаємодії з OBS використовується вбудований WebSocket сервер. За замовчуванням він вимкнений. Відкрийте OBS і перейдіть в налаштування WebSocket Server Settings.
![plot](./images/obs_websocket_open.jpg)
7. Активуйте WebSocket сервер, в Show Connect Info скопіюйте пароль і збережість налаштування.
![plot](./images/obs_websocket_config.jpg)
8. В застосунку введіть пароль від OBS WebSocket серверу і підлючіться кнопкою Connect. Якщо все правильно зробили - в OBS WebSocket Server Settings побачите нову сесію, а в застосунку - зелений індикатор.
![plot](./images/obs_websocket_connected.jpg)
9. Готово. Програма готова для роботи :)