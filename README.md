Programator AVR i EEPROM przez USB
==================================

Programator zbudowany na AT89C4051, podłączany do hosta USB przez
przejściówkę USB-TTL, potrafi czytać i zapisywać AVR (np. ATTiny2313)
oraz kości EEPROM na I²C (np. AT24C02) i SPI (93C46N), a także
komunikować się z urządzeniami 1-wire.

Przejściówka USB-TTL tworzy w PC wirtualny port szeregowy.
Programator komunikuje się z PC przez ten port protokołem zgodnym
z tym używanym w mikrokontrolerach DS89C4X0, który jest opisany
w Ultra-High-Speed Flash Microcontroller User's Guide ([USER GUIDE 4833]).
Zawartość pamięci jest wymieniana w formacie Intel HEX.

Użyty asembler: [asem-51]

![img-top] ![img-bottom]

Opcje kompilacji
----------------

TODO

Obsługiwane polecenia
---------------------

TODO

Licencja
========

This file is part of Programator.

Programator is free software: you can redistribute it and/or
modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

Programator is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the [GNU General Public License]
along with Programator. If not, see <https://www.gnu.org/licenses/>.

[GNU General Public License]: LICENSE.md
[asem-51]: http://plit.de/asem-51
[USER GUIDE 4833]: https://www.maximintegrated.com/en/design/technical-documents/userguides-and-manuals/4/4833.html
[img-top]: img/programator-top.jpg
[img-bottom]: img/programator-bottom.jpg
