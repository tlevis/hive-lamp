#include "Hive.h"

Hive hive;

void setup()
{
    Serial.begin(115200);
    hive.setup();
}

void loop()
{
    hive.run();
}
