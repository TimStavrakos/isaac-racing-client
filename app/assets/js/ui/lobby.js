/*
    Lobby screen
*/

'use strict';

// Imports
const fs      = nodeRequire('fs');
const os      = nodeRequire('os');
const path    = nodeRequire('path');
const spawn   = nodeRequire('child_process').spawn;
const shell   = nodeRequire('electron').shell;
const Tail    = nodeRequire('tail').Tail;
const globals = nodeRequire('./assets/js/globals');
const misc    = nodeRequire('./assets/js/misc');
const chat    = nodeRequire('./assets/js/chat');

/*
    Event handlers
*/

$(document).ready(function() {
    $('#lobby-chat-form').submit(function(event) {
        // By default, the form will reload the page, so stop this from happening
        event.preventDefault();

        // Validate input and send the chat
        chat.send('lobby');
    });
});

/*
    Lobby functions
*/

// Called from the login screen or the register screen
exports.show = function() {
    // Check to make sure the log file exists
    if (fs.existsSync(globals.settings.logFilePath) === false) {
        globals.settings.logFilePath = null;
    }

    // Check to ensure that we have a valid log file path
    if (globals.settings.logFilePath === null ) {
        misc.errorShow('', true); // Show the log file path modal
        return;
    }

    // Start the log monitoring program
    console.log('Starting the log monitoring program...');
    let command = path.join(__dirname, '../../programs/watchLog/dist/watchLog.exe');
    globals.logMonitoringProgram = spawn(command, [globals.settings.logFilePath]);

    // Tail the IPC file
    let logWatcher = new Tail(path.join(os.tmpdir(), 'Racing+_IPC.txt'));
    logWatcher.on('line', function(line) {
        // Debug
        //console.log('- ' + line);

        // Don't do anything if we are not in a race
        if (globals.currentRaceID === false) {
            return;
        }

        // Don't do anything if we have not started yet or we have quit
        for (let i = 0; i < globals.raceList[globals.currentRaceID].racerList.length; i++) {
            if (globals.raceList[globals.currentRaceID].racerList[i].name === globals.myUsername) {
                if (globals.raceList[globals.currentRaceID].racerList[i].status !== 'racing') {
                    return;
                }
                break;
            }
        }

        // Parse the line
        if (line.startsWith('New seed: ')) {
            let m = line.match(/New seed: (.... ....)/);
            if (m) {
                let seed = m[1];
                console.log('New seed:', seed);
                globals.conn.emit('raceSeed', {
                    'id':   globals.currentRaceID,
                    'seed': seed,
                });
            } else {
                misc.errorShow('Failed to parse the new seed.');
            }
        } else if (line.startsWith('New floor: ')) {
            let m = line.match(/New floor: (\d+)-\d+/);
            if (m) {
                let floor = m[1];
                console.log('New floor:', floor);
                globals.conn.emit('raceFloor', {
                    'id':    globals.currentRaceID,
                    'floor': floor,
                });
            } else {
                misc.errorShow('Failed to parse the new floor.');
            }
        } else if (line.startsWith('New room: ')) {
            let m = line.match(/New room: (\d+)/);
            if (m) {
                let room = m[1];
                console.log('New room:', room);
                globals.conn.emit('raceFloor', {
                    'id':   globals.currentRaceID,
                    'room': room,
                });
            } else {
                misc.errorShow('Failed to parse the new room.');
            }
        } else if (line.startsWith('New item: ')) {
            let m = line.match(/New item: (\d+)/);
            if (m) {
                let itemID = m[1];
                console.log('New item:', itemID);
                globals.conn.emit('raceItem', {
                    'id':   globals.currentRaceID,
                    'itemID': itemID,
                });
            } else {
                misc.errorShow('Failed to parse the new item.');
            }
        } else if (line === 'Finished run: Blue Baby') {
            if (globals.raceList[globals.currentRaceID].ruleset.goal === 'Blue Baby') {
                console.log('Killed Blue Baby!');
                globals.conn.emit('raceFinish', {
                    'id': globals.currentRaceID,
                });
            }
        } else if (line === 'Finished run: The Lamb') {
            if (globals.raceList[globals.currentRaceID].ruleset.goal === 'The Lamb') {
                console.log('Killed The Lamb!');
                globals.conn.emit('raceFinish', {
                    'id': globals.currentRaceID,
                });
            }
        } else if (line === 'Finished run: Mega Satan') {
            if (globals.raceList[globals.currentRaceID].ruleset.goal === 'Mega Satan') {
                console.log('Killed Mega Satan!');
                globals.conn.emit('raceFinish', {
                    'id': globals.currentRaceID,
                });
            }
        }
    });
    logWatcher.on('error', function(error) {
        misc.errorShow('Something went wrong with the log monitoring program: "' + error);
    });

    // Make sure that all of the forms are cleared out
    $('#login-username').val('');
    $('#login-password').val('');
    $('#login-remember-checkbox').prop('checked', false);
    $('#login-error').fadeOut(0);
    $('#register-username').val('');
    $('#register-password').val('');
    $('#register-email').val('');
    $('#register-error').fadeOut(0);

    // Show the links in the header
    $('#header-profile').fadeIn(globals.fadeTime);
    $('#header-leaderboards').fadeIn(globals.fadeTime);
    $('#header-help').fadeIn(globals.fadeTime);

    // Show the buttons in the header
    $('#header-new-race').fadeIn(globals.fadeTime);
    $('#header-settings').fadeIn(globals.fadeTime);
    $('#header-log-out').fadeIn(globals.fadeTime);

    // Show the lobby
    $('#page-wrapper').removeClass('vertical-center');
    $('#lobby').fadeIn(globals.fadeTime, function() {
        globals.currentScreen = 'lobby';
    });

    // Fix the indentation on lines that were drawn when the element was hidden
    chatIndent('lobby');

    // Automatically scroll to the bottom of the chat box
    let bottomPixel = $('#lobby-chat-text').prop('scrollHeight') - $('#lobby-chat-text').height();
    $('#lobby-chat-text').scrollTop(bottomPixel);

    // Focus the chat input
    $('#lobby-chat-box-input').focus();
};

exports.showFromRace = function() {
    // We should be on the race screen unless there is severe lag
    if (globals.currentScreen !== 'race') {
        misc.errorShow('Failed to return to the lobby since currentScreen is equal to "' + globals.currentScreen + '".');
        return;
    }
    globals.currentScreen = 'transition';
    globals.currentRaceID = false;

    // Show and hide some buttons in the header
    $('#header-profile').fadeOut(globals.fadeTime);
    $('#header-leaderboards').fadeOut(globals.fadeTime);
    $('#header-help').fadeOut(globals.fadeTime);
    $('#header-lobby').fadeOut(globals.fadeTime, function() {
        $('#header-profile').fadeIn(globals.fadeTime);
        $('#header-leaderboards').fadeIn(globals.fadeTime);
        $('#header-help').fadeIn(globals.fadeTime);
        $('#header-new-race').fadeIn(globals.fadeTime);
        $('#header-settings').fadeIn(globals.fadeTime);
    });

    // Show the lobby
    $('#race').fadeOut(globals.fadeTime, function() {
        $('#lobby').fadeIn(globals.fadeTime, function() {
            globals.currentScreen = 'lobby';
        });

        // Fix the indentation on lines that were drawn when the element was hidden
        chatIndent('lobby');

        // Automatically scroll to the bottom of the chat box
        let bottomPixel = $('#lobby-chat-text').prop('scrollHeight') - $('#lobby-chat-text').height();
        $('#lobby-chat-text').scrollTop(bottomPixel);

        // Focus the chat input
        $('#lobby-chat-box-input').focus();
    });
};

exports.raceDraw = function(race) {
    // Create the new row
    let raceDiv = '<tr id="lobby-current-races-' + race.id + '" class="';
    if (race.status === 'open') {
        raceDiv += 'lobby-race-row-open ';
    }
    raceDiv += 'hidden"><td>Race ' + race.id;
    if (race.name !== '-') {
        raceDiv += ' &mdash; ' + race.name;
    }
    raceDiv += '</td><td>';
    let circleClass;
    if (race.status === 'open') {
        circleClass = 'open';
    } else if (race.status === 'starting') {
        circleClass = 'starting';
    } else if (race.status === 'in progress') {
        circleClass = 'in-progress';
    }
    raceDiv += '<span id="lobby-current-races-' + race.id + '-status-circle" class="circle lobby-current-races-' + circleClass + '"></span>';
    raceDiv += ' &nbsp; <span id="lobby-current-races-' + race.id + '-status">' + race.status.capitalize() + '</span>';
    raceDiv += '</td><td id="lobby-current-races-' + race.id + '-racers">' + race.racers.length + '</td>';
    raceDiv += '<td><span class="lobby-current-races-format-icon">';
    raceDiv += '<span class="lobby-current-races-' + race.ruleset.format + '"></span></span>';
    raceDiv += '<span class="lobby-current-races-spacing"></span>';
    raceDiv += '<span lang="en">' + race.ruleset.format.capitalize() + '</span></td>';
    raceDiv += '<td id="lobby-current-races-' + race.id + '-captain">' + race.captain + '</td></tr>';

    // Fade in the new row
    $('#lobby-current-races-table-body').append(raceDiv);
    if ($('#lobby-current-races-table-no').css('display') !== 'none') {
        $('#lobby-current-races-table-no').fadeOut(globals.fadeTime, function() {
            $('#lobby-current-races-table').fadeIn(0);
            $('#lobby-current-races-' + race.id).fadeIn(globals.fadeTime, function() {
                lobbyRaceRowClickable(race.id);
            });
        });
    } else {
        $('#lobby-current-races-' + race.id).fadeIn(globals.fadeTime, function() {
            lobbyRaceRowClickable(race.id);
        });
    }

    // Make it clickable
    function lobbyRaceRowClickable(raceID) {
        if (globals.raceList[raceID].status === 'open') {
            $('#lobby-current-races-' + raceID).click(function() {
                globals.conn.emit('raceJoin', {
                    'id': raceID,
                });
            });
        }
    }
};

exports.raceUndraw = function(raceID) {
    $('#lobby-current-races-' + raceID).fadeOut(globals.fadeTime, function() {
        $('#lobby-current-races-' + raceID).remove();

        if (Object.keys(globals.raceList).length === 0) {
            $('#lobby-current-races-table').fadeOut(0);
            $('#lobby-current-races-table-no').fadeIn(globals.fadeTime);
        }
    });
};

function chatIndent(room) {
    if (typeof globals.roomList[room] === 'undefined') {
        return;
    }

    for (let i = 1; i <= globals.roomList[room].chatLine; i++) {
        let indentPixels = $('#' + room + '-chat-text-line-' + i + '-header').css('width');
        $('#' + room + '-chat-text-line-' + i).css('padding-left', indentPixels);
        $('#' + room + '-chat-text-line-' + i).css('text-indent', '-' + indentPixels);
    }
}

exports.usersDraw = function(room) {
    // Update the header that shows shows the amount of people online or in the race
    $('#lobby-users-online').html(globals.roomList[room].numUsers);

    // Make an array with the name of every user and alphabetize it
    let userList = [];
    for (let user in globals.roomList[room].users) {
        if (globals.roomList[room].users.hasOwnProperty(user)) {
            userList.push(user);
        }
    }
    userList.sort();

    // Empty the existing list
    $('#lobby-users-users').html('');

    // Add a div for each player
    for (let i = 0; i < userList.length; i++) {
        if (userList[i] === globals.myUsername) {
            let userDiv = '<div>' + userList[i] + '</div>';
            $('#lobby-users-users').append(userDiv);
        } else {
            let userDiv = '<div id="lobby-users-' + userList[i] + '" class="users-user" data-tooltip-content="#user-click-tooltip">';
            userDiv += userList[i] + '</div>';
            $('#lobby-users-users').append(userDiv);

            // Add the tooltip
            $('#lobby-users-' + userList[i]).tooltipster({
                theme: 'tooltipster-shadow',
                trigger: 'click',
                interactive: true,
                side: 'left',
                functionBefore: userTooltipChange(userList[i]),
            });
        }
    }

    function userTooltipChange(username) {
        $('#user-click-profile').click(function() {
            let url = 'http' + (globals.secure ? 's' : '') + '://' + globals.domain + '/profiles/' + username;
            shell.openExternal(url);
        });
        $('#user-click-private-message').click(function() {
            if (globals.currentScreen === 'lobby') {
                $('#lobby-chat-box-input').val('/msg ' + username + ' ');
                $('#lobby-chat-box-input').focus();
            } else if (globals.currentScreen === 'race') {
                $('#race-chat-box-input').val('/msg ' + username + ' ');
                $('#race-chat-box-input').focus();
            } else {
                misc.errorShow('Failed to fill in the chat box since currentScreen is "' + globals.currentScreen + '".');
            }
            misc.closeAllTooltips();
        });
    }
};
