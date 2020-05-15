var WebSocketClient  = require('websocket').client;


var currentVersion = "0.0.17";

var wsClient = new WebSocketClient();

var msg = {
    Value: "#FF0000"
};

var updateFirmware = {
    Command: "FIRMWARE_UPDATE",
    Value: `http://hive.tovilevis.com/hive_fw_v${currentVersion}.bin`
};

var cylon = {
    Name: "Cylon",
    Color: "F00FF0",
    Delay: 60,
	Duration: 0,
	Position: 0,
	Direction: 1,
	Brightness: 0,
	MaxBrightness: 127
};

var breathing = {
    Name: "Breathing",
    Color: "F00FF0",
    Delay: 10,
	Duration: 0,
	Direction: 1,
	Brightness: 0,
	MaxBrightness: 250
	
};

var swirl = {
    Name: "Swirl",
    Color1: "0000BB",
    Color2: "00BB00",	
    Delay: 80,
	Duration: 0,
	Position: 0,
	Brightness: 0,
	MaxBrightness: 127
	
};

var rainbow = {
    Name: "Rainbow",
    Delay: 2,
	Duration: 0,
	Position: 255,
	Brightness: 0,
	MaxBrightness: 127
	
};
var solidRed = { 
    Name: "Solid",
    Color: "FF0000",
	Executed: false
};

var turnoff = { 
    Name: "Solid",
    Color: "000000",
	Executed: false
};



var selectedProgram = rainbow;
var runProgram = true;
wsClient.on('connect', function(connection)
{
    console.log("Connected");
    connection.on('error', function(error) {
        console.log(error);
    });
    
    connection.on('close', function(code, description) {
        console.log(`Connection Closed (${code}): ${description}`);
    });
    
    connection.on('message', function(message) {
        console.log(message);
        if (message.utf8Data != "") {
            var oData = JSON.parse(message.utf8Data);

            if (oData.hasOwnProperty("FIRMWARE")) {
                console.log(`Device Firmware: ${oData["FIRMWARE"]}`);
                if (currentVersion != oData["FIRMWARE"]) {
					runProgram = false;
                    console.log(`Updating to ${currentVersion}`);
                    connection.send(JSON.stringify(updateFirmware));
                }
            }
        }
    });

    setTimeout(() => {
		if (runProgram) {
			console.log(`running ${selectedProgram.Name}`);
			var data = { Command: "PROGRAM", Value: selectedProgram };
			connection.send(JSON.stringify(data));
			//connection.send(JSON.stringify(updateFirmware));		
		}
    }, 1000);
});

const wsURL = `ws://10.0.0.111:5656`;


wsClient.connect(wsURL);


