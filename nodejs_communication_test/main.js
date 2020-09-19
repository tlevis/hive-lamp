var WebSocketClient  = require('websocket').client;

var myArgs = process.argv.slice(2);
var argProgram = "";
if (myArgs.length > 0) {
	argProgram = myArgs[0];
}else{
	console.log("Missing args");
	exit(0);
}


var currentVersion = { 
    "Hive" : "0.0.17",
    "Hive_Nano" : "0.0.20"
};


var wsClient = new WebSocketClient();

var msg = {
    Value: "#FF0000"
};

// var updateFirmware = {
//     Command: "FIRMWARE_UPDATE",
//     Value: `http://hive.tovilevis.com/hive_fw_v${currentVersion}.bin`
// };

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
    Color: "00420e",
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

var programs = {
	"breathing": breathing,
	"swirl": swirl,
	"rainbow": rainbow, 
	"solidRed": solidRed,
	"turnoff": turnoff
}

function UpdateFirmwareCommand(deviceType) {
    var msg = { 
        Command: "FIRMWARE_UPDATE",
        Value: `http://hive.tovilevis.com/hive_fw_${deviceType}_v${currentVersion[deviceType]}.bin`
    }
    return msg;
}

console.log(`Selected: ${argProgram}`);
var selectedProgram = programs[argProgram];// turnoff;
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
            var deviceType = "Hive"; // Default device for backward compatibility
            if (oData.hasOwnProperty("DEVICE_TYPE")) {
                deviceType = oData["DEVICE_TYPE"];
            }

            if (oData.hasOwnProperty("FIRMWARE")) {
                console.log(`Device Firmware: ${oData["FIRMWARE"]}`);
                if (currentVersion[deviceType] != oData["FIRMWARE"]) {
					runProgram = false;
                    console.log(`Updating ${deviceType} to ${currentVersion[deviceType]}`);
                    connection.send(JSON.stringify(UpdateFirmwareCommand(deviceType)));
                }
            }

            if (oData.hasOwnProperty("PERCENTAGE")) {
                console.log(`Battery: ${oData["PERCENTAGE"]}% (${oData["VOLTS"]}v)`);
            }            

            
        }
    });

    setTimeout(() => {
        var data = { Command: "BATTERY", Value: "" };
        connection.send(JSON.stringify(data));
    }, 100);    

    setTimeout(() => {
		if (runProgram) {
			console.log(`running ${selectedProgram.Name}`);
			var data = { Command: "PROGRAM", Value: selectedProgram };
			connection.send(JSON.stringify(data));
			setTimeout(function() { process.exit(); }, 1000);
			//connection.send(JSON.stringify(updateFirmware));		
		}
    }, 1000);
});

const wsURL = `ws://10.0.0.111:5656`;


wsClient.connect(wsURL);


