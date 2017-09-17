/*
    Racing+ Client
    for The Binding of Isaac: Afterbirth+
    (main process)
*/

/*

Send me your Isaac `log.txt file`, which is located here:
```
C:\Users\james\Documents\My Games\Binding of Isaac Afterbirth+\log.txt
```
And send me your Racing+ log file, which is located here:
```
C:\Users\james\AppData\Local\Programs\Racing+.log
```
And if you are still in the race, send me your `save1.dat` file (for save slot #1), which is located here:
```
C:\Users\james\Documents\My Games\Binding of Isaac Afterbirth+ Mods\racing+_857628390\save1.dat
```

*/

// Settings file location:
// C:\Users\james\AppData\Local\Programs\settings.json

// Build:
// npm run dist --python="C:\Python27\python.exe"
// Build and upload to GitHub:
// npm run dist2 --python="C:\Python27\python.exe"

// Reinstall NPM dependencies:
// (ncu updates the package.json, so blow away everything and reinstall)
// ncu -a && rm -rf node_modules && npm install --python="C:\Python27\python.exe"

// Count lines of code:
// cloc . --exclude-dir .git,dist,node_modules,css,fonts,words

// Convert corrupted PNGs with ImageMagick:
// http://forums.gamesalad.com/discussion/67365/problems-with-png-images-use-these-methods-to-fix-your-pngs
// sips --deleteColorManagementProperties ###.png

// List of files to update during Booster Packs:
// 1) data/items.json
// 2) img/items/#.png
// 3) mod/content/items.xml
// 4) mod/resources/gfx/items2/..
// 5) mod/resources/gfx/items3/..

/*

Other notes:
- Electron 1.7.6 gives error with graceful-fs, so staying on version

*/


// Imports
const {
    app,
    BrowserWindow,
    ipcMain,
    globalShortcut,
} = require('electron'); // eslint-disable-line import/no-extraneous-dependencies
// The "electron" package is only allowed to be in the devDependencies section
const { autoUpdater } = require('electron-updater'); // Import electron-builder's autoUpdater as opposed to the generic electron autoUpdater
// See: https://github.com/electron-userland/electron-builder/wiki/Auto-Update
const { execFile, fork } = require('child_process');
const fs = require('fs-extra');
const path = require('path');
const isDev = require('electron-is-dev');
const tracer = require('tracer');
const Raven = require('raven');
const teeny = require('teeny-conf');
const opn = require('opn');
const globals = require('./js/globals.js');

// Global variables
let mainWindow;
// Keep a global reference of the window object
// (otherwise the window will be closed automatically when the JavaScript object is garbage collected)
let childLogWatcher = null;
let childSteamWatcher = null;
let childSteam = null;
let childIsaac = null;
let errorHappened = false;

// Logging (code duplicated between main and renderer because of require/nodeRequire issues)
let logRoot;
if (isDev) {
    // For development, this puts the log file in the root of the repository
    logRoot = path.join(__dirname, '..');
} else {
    // For production, this puts the log file in the "Programs" directory
    // (the __dirname is "C:\Users\[Username]\AppData\Local\Programs\RacingPlus\resources\app.asar\src")
    logRoot = path.join(__dirname, '..', '..', '..', '..');
}
const log = tracer.dailyfile({
    // Log file settings
    root: logRoot,
    logPathFormat: '{{root}}/Racing+ {{date}}.log',
    splitFormat: 'yyyy-mm-dd',
    maxLogFiles: 10,

    // Global tracer settings
    format: '{{timestamp}} <{{title}}> {{file}}:{{line}} - {{message}}',
    dateformat: 'ddd mmm dd HH:MM:ss Z',
    transport: (data) => {
        // Log errors to the JavaScript console in addition to the log file
        console.log(data.output);
    },
});

// Get the version
const packageFileLocation = path.join(__dirname, '..', 'package.json');
const packageFile = fs.readFileSync(packageFileLocation, 'utf8');
const version = `v${JSON.parse(packageFile).version}`;

const middleLine = `Racing+ client ${version} started!`;
let separatorLine = '';
for (let i = 0; i < middleLine.length; i++) {
    separatorLine += '-';
}
log.info(`+-${separatorLine}-+`);
log.info(`| ${middleLine} |`);
log.info(`+-${separatorLine}-+`);

// Raven (error logging to Sentry)
Raven.config('https://0d0a2118a3354f07ae98d485571e60be:843172db624445f1acb86908446e5c9d@sentry.io/124813', {
    autoBreadcrumbs: true,
    release: version,
    environment: (isDev ? 'development' : 'production'),
    dataCallback: (data) => {
        log.error(data);
        return data;
    },
}).install();

/*
    Settings (through persistent storage)
*/

// Open the file that contains all of the user's settings
const settingsFile = path.join(logRoot, 'settings.json'); // This will be created if it does not exist already
const settings = new teeny(settingsFile); // eslint-disable-line new-cap
settings.loadOrCreateSync();

/*
    Subroutines
*/

function createWindow() {
    // Figure out what the window size and position should be
    if (typeof settings.get('window') === 'undefined') {
        // If this is the first run, create an empty window object
        settings.set('window', {});
        settings.saveSync();
    }
    const windowSettings = settings.get('window');

    // Width
    let width;
    if (Object.prototype.hasOwnProperty.call(windowSettings, 'width')) {
        ({ width } = windowSettings);
    } else {
        width = (isDev ? 1610 : 1110);
    }

    // Height
    let height;
    if (Object.prototype.hasOwnProperty.call(windowSettings, 'height')) {
        ({ height } = windowSettings);
    } else {
        height = 720;
    }

    // Create the browser window
    mainWindow = new BrowserWindow({
        x: windowSettings.x,
        y: windowSettings.y,
        width,
        height,
        icon: path.resolve(__dirname, 'img', 'favicon.png'),
        title: 'Racing+',
        frame: false,
    });
    if (isDev) {
        mainWindow.webContents.openDevTools();
    }
    mainWindow.loadURL(`file://${__dirname}/index.html`);

    // Remove the taskbar flash state
    // (this is not currently used)
    mainWindow.once('focus', () => {
        mainWindow.flashFrame(false);
    });

    // Save the window size and position
    mainWindow.on('close', () => {
        const windowBounds = mainWindow.getBounds();

        // We have to re-get the settings, since the renderer process may have changed them
        // If so, our local copy of all of the settings is no longer current
        settings.loadOrCreateSync();
        settings.set('window', windowBounds);
        settings.saveSync();
    });

    // Dereference the window object when it is closed
    mainWindow.on('closed', () => {
        mainWindow = null;
    });
}

function autoUpdate() {
    // Now that the window is created, check for updates
    if (!isDev) {
        autoUpdater.on('error', (err) => {
            log.error(err.message);
            Raven.captureException(err);
            mainWindow.webContents.send('autoUpdater', 'error');
        });

        autoUpdater.on('checking-for-update', () => {
            mainWindow.webContents.send('autoUpdater', 'checking-for-update');
        });

        autoUpdater.on('update-available', () => {
            mainWindow.webContents.send('autoUpdater', 'update-available');
        });

        autoUpdater.on('update-not-available', () => {
            mainWindow.webContents.send('autoUpdater', 'update-not-available');
        });

        autoUpdater.on('update-downloaded', (info) => {
            log.info('updated-downloaded:', info);
            mainWindow.webContents.send('autoUpdater', 'update-downloaded');
        });

        log.info('Checking for updates.');
        autoUpdater.checkForUpdates();
    }
}

function registerKeyboardHotkeys() {
    // Register global hotkeys
    const hotkeyIsaacLaunch = globalShortcut.register('Alt+B', () => {
        opn('steam://rungameid/250900');
    });
    if (!hotkeyIsaacLaunch) {
        log.warn('Alt+B hotkey registration failed.');
    }

    const hotkeyIsaacFocus = globalShortcut.register('Alt+1', () => {
        if (process.platform === 'win32') { // This will return "win32" even on 64-bit Windows
            const pathToFocusIsaac = path.join(__dirname, 'programs', 'focusIsaac', 'focusIsaac.exe');
            execFile(pathToFocusIsaac, (error, stdout, stderr) => {
                // We have to attach an empty callback to this or it does not work for some reason
            });
        }
    });
    if (!hotkeyIsaacFocus) {
        log.warn('Alt+1 hotkey registration failed.');
    }

    const hotkeyRacingPlusFocus = globalShortcut.register('Alt+2', () => {
        mainWindow.focus();
    });
    if (!hotkeyRacingPlusFocus) {
        log.warn('Alt+2 hotkey registration failed.');
    }

    const hotkeyReady = globalShortcut.register('Alt+R', () => {
        mainWindow.webContents.send('hotkey', 'ready');
    });
    if (!hotkeyReady) {
        log.warn('Alt+R hotkey registration failed.');
    }

    const hotkeyFinish = globalShortcut.register('Alt+F', () => {
        mainWindow.webContents.send('hotkey', 'finish');
    });
    if (!hotkeyFinish) {
        log.warn('Alt+F hotkey registration failed.');
    }

    const hotkeyQuit = globalShortcut.register('Alt+Q', () => {
        mainWindow.webContents.send('hotkey', 'quit');
    });
    if (!hotkeyQuit) {
        log.warn('Alt+Q hotkey registration failed.');
    }
}

/*
    Application handlers
*/

// Check to see if the application is already open
if (!isDev) {
    const shouldQuit = app.makeSingleInstance((commandLine, workingDirectory) => {
        // A second instance of the program was opened, so just focus the existing window
        if (mainWindow) {
            if (mainWindow.isMinimized()) mainWindow.restore();
            mainWindow.focus();
        }
    });
    if (shouldQuit) {
        app.quit();
    }
}

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on('ready', () => {
    createWindow();
    autoUpdate();
    registerKeyboardHotkeys();
});

// Quit when all windows are closed.
app.on('window-all-closed', () => {
    // On OS X it is common for applications and their menu bar
    // to stay active until the user quits explicitly with Cmd + Q
    if (process.platform !== 'darwin') {
        app.quit();
    }
});

app.on('activate', () => {
    // On OS X it's common to re-create a window in the app when the
    // dock icon is clicked and there are no other windows open.
    if (mainWindow === null) {
        createWindow();
    }
});

app.on('before-quit', () => {
    if (!errorHappened) {
        // Write all default values to the "save1.dat", "save2.dat", and "save3.dat" files
        let modsPath;
        if (process.platform === 'linux') {
            modsPath = path.join(path.dirname(settings.get('logFilePath')), '..', 'binding of isaac afterbirth+ mods');
        } else {
            modsPath = path.join(path.dirname(settings.get('logFilePath')), '..', 'Binding of Isaac Afterbirth+ Mods');
        }
        for (let i = 1; i <= 3; i++) {
            // Find the location of the file
            let saveDat = path.join(modsPath, globals.modNameDev, `save${i}.dat`);
            if (!fs.existsSync(saveDat)) {
                saveDat = path.join(modsPath, globals.modName, `save${i}.dat`);
            }

            // Read it and set all non-speedrun order variables to defaults
            const json = JSON.parse(fs.readFileSync(saveDat, 'utf8'));
            json.status = 'none';
            json.myStatus = 'not ready';
            json.rType = 'unranked';
            json.solo = false;
            json.rFormat = 'unseeded';
            json.character = 3;
            json.goal = 'Blue Baby';
            json.seed = '-';
            json.startingItems = [];
            json.countdown = -1;
            json.placeMid = 0;
            json.place = 1;
            if (typeof json.order7 === 'undefined') {
                json.order7 = [0];
            }
            if (typeof json.order9 === 'undefined') {
                json.order9 = [0];
            }
            if (typeof json.order14 === 'undefined') {
                json.order14 = [0];
            }
            try {
                fs.writeFileSync(saveDat, JSON.stringify(json), 'utf8');
            } catch (err) {
                log.error(`Error while writing the "save${i}.dat" file: ${err}`);
            }
        }
        log.info('Copied over default "save1.dat", "save2.dat", and "save3.dat" files.');
    } else {
        log.info('Not copying over the 3 default "save.dat" files since we got an error.');
    }
});

app.on('will-quit', () => {
    // Unregister the global keyboard hotkeys
    globalShortcut.unregisterAll();

    // Tell the child processes to exit (in Node, they will live forever even if the parent closes)
    if (childSteam !== null) {
        childSteam.send('exit');
    }
    if (childLogWatcher !== null) {
        childLogWatcher.send('exit');
    }
    if (childSteamWatcher !== null) {
        childSteamWatcher.send('exit');
    }
    if (childIsaac !== null) {
        childIsaac.send('exit');
    }
});

/*
    IPC handlers
*/

ipcMain.on('asynchronous-message', (event, arg1, arg2) => {
    log.info('Main process recieved message:', arg1);

    if (arg1 === 'minimize') {
        mainWindow.minimize();
    } else if (arg1 === 'maximize') {
        if (mainWindow.isMaximized()) {
            mainWindow.unmaximize();
        } else {
            mainWindow.maximize();
        }
    } else if (arg1 === 'close') {
        app.quit();
    } else if (arg1 === 'restart') {
        errorHappened = true; // Don't reset our 3 "save.dat" files if we did a /restart
        app.relaunch();
        app.quit();
    } else if (arg1 === 'quitAndInstall') {
        autoUpdater.quitAndInstall();
    } else if (arg1 === 'devTools') {
        mainWindow.webContents.openDevTools();
    } else if (arg1 === 'error') {
        errorHappened = true;
    } else if (arg1 === 'steam' && childSteam === null) {
        // Initialize the Greenworks API in a separate process because otherwise the game will refuse to open if Racing+ is open
        // (Greenworks uses the same AppID as Isaac, so Steam gets confused)
        if (isDev) {
            childSteam = fork('./src/steam');
        } else {
            // There are problems when forking inside of an ASAR archive
            // See: https://github.com/electron/electron/issues/2708
            childSteam = fork('./app.asar/src/steam', {
                cwd: path.join(__dirname, '..', '..'),
            });
        }
        log.info('Started the Greenworks child process.');

        // Receive notifications from the child process
        childSteam.on('message', (message) => {
            // Pass the message to the renderer (browser) process
            mainWindow.webContents.send('steam', message);
        });

        // Track errors
        childSteam.on('error', (err) => {
            // Pass the error to the renderer (browser) process
            mainWindow.webContents.send('steam', `error: ${err}`);
        });

        // Track when the process exits
        childSteam.on('exit', () => {
            mainWindow.webContents.send('steam', 'exited');
        });
    } else if (arg1 === 'steamExit') {
        // The renderer has successfully authenticated and is now establishing a WebSocket connection, so we can kill the Greenworks process
        if (childSteam !== null) {
            childSteam.send('exit');
        }
    } else if (arg1 === 'logWatcher' && childLogWatcher === null) {
        // Start the log watcher in a separate process for performance reasons
        if (isDev) {
            childLogWatcher = fork('./src/log-watcher');
        } else {
            // There are problems when forking inside of an ASAR archive
            // See: https://github.com/electron/electron/issues/2708
            childLogWatcher = fork('./app.asar/src/log-watcher', {
                cwd: path.join(__dirname, '..', '..'),
            });
        }
        log.info('Started the log watcher child process.');

        // Receive notifications from the child process
        childLogWatcher.on('message', (message) => {
            // Pass the message to the renderer (browser) process
            mainWindow.webContents.send('logWatcher', message);
        });

        // Track errors
        childLogWatcher.on('error', (err) => {
            // Pass the error to the renderer (browser) process
            mainWindow.webContents.send('logWatcher', `error: ${err}`);
        });

        // Feed the child the path to the Isaac log file
        childLogWatcher.send(arg2);
    } else if (arg1 === 'steamWatcher' && childSteamWatcher === null) {
        // Start the log watcher in a separate process for performance reasons
        if (isDev) {
            childSteamWatcher = fork('./src/steam-watcher');
        } else {
            // There are problems when forking inside of an ASAR archive
            // See: https://github.com/electron/electron/issues/2708
            childSteamWatcher = fork('./app.asar/src/steam-watcher', {
                cwd: path.join(__dirname, '..', '..'),
            });
        }
        log.info('Started the Steam watcher child process.');

        // Receive notifications from the child process
        childSteamWatcher.on('message', (message) => {
            // Pass the message to the renderer (browser) process
            mainWindow.webContents.send('steamWatcher', message);
        });

        // Track errors
        childSteamWatcher.on('error', (err) => {
            // Pass the error to the renderer (browser) process
            mainWindow.webContents.send('steamWatcher', `error: ${err}`);
        });

        // Feed the child the ID of the Steam user
        childSteamWatcher.send(arg2);
    } else if (arg1 === 'isaac') {
        // Start the Isaac launcher in a separate process for performance reasons
        if (isDev) {
            childIsaac = fork('./src/isaac');
        } else {
            // There are problems when forking inside of an ASAR archive
            // See: https://github.com/electron/electron/issues/2708
            childIsaac = fork('./app.asar/src/isaac', {
                cwd: path.join(__dirname, '..', '..'),
            });
        }
        log.info('Started the Isaac launcher child process with an argument of:', arg2);

        // Receive notifications from the child process
        childIsaac.on('message', (message) => {
            // Pass the message to the renderer (browser) process
            mainWindow.webContents.send('isaac', message);
        });

        // Track errors
        childIsaac.on('error', (err) => {
            // Pass the error to the renderer (browser) process
            mainWindow.webContents.send('isaac', `error: ${err}`);
        });

        // Feed the child the path to the Isaac mods directory and the "force" boolean
        childIsaac.send(arg2);
    }
});
