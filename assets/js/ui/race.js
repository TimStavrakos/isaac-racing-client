/*
    Race screen
*/

'use strict';

// Imports
const execFile  = nodeRequire('child_process').execFile;
const path      = nodeRequire('path');
const clipboard = nodeRequire('electron').clipboard;
const globals   = nodeRequire('./assets/js/globals');
const misc      = nodeRequire('./assets/js/misc');
const chat      = nodeRequire('./assets/js/chat');

/*
    Event handlers
*/

$(document).ready(function() {
    $('#race-title').tooltipster({
        theme: 'tooltipster-shadow',
        delay: 0,
        functionBefore: function() {
            if (globals.currentScreen === 'race') {
                return true;
            } else {
                return false;
            }
        },
    });

    $('#race-title-type-icon').tooltipster({
        theme: 'tooltipster-shadow',
        delay: 0,
        contentAsHTML: true,
        functionBefore: function() {
            if (globals.currentScreen === 'race') {
                return true;
            } else {
                return false;
            }
        },
    });

    $('#race-title-format-icon').tooltipster({
        theme: 'tooltipster-shadow',
        delay: 0,
        contentAsHTML: true,
        functionBefore: function() {
            if (globals.currentScreen === 'race') {
                return true;
            } else {
                return false;
            }
        },
    });

    $('#race-title-goal-icon').tooltipster({
        theme: 'tooltipster-shadow',
        delay: 0,
        contentAsHTML: true,
        functionBefore: function() {
            if (globals.currentScreen === 'race') {
                return true;
            } else {
                return false;
            }
        },
    });

    $('#race-title-seed').tooltipster({
        theme: 'tooltipster-shadow',
        delay: 0,
        functionBefore: function() {
            if (globals.currentScreen === 'race') {
                return true;
            } else {
                return false;
            }
        },
    });

    $('#race-ready-checkbox').change(function() {
        if (globals.currentScreen !== 'race') {
            return;
        } else if (globals.raceList.hasOwnProperty(globals.currentRaceID) === false) {
            return;
        } else if (globals.raceList[globals.currentRaceID].status !== 'open') {
            return;
        }

        // Don't allow people to spam this
        let now = new Date().getTime();
        if (now - globals.spamTimer < 1000) {
            // Undo what they did
            if ($('#race-ready-checkbox').is(':checked')) {
                $('#race-ready-checkbox').prop('checked', false);
            } else {
                $('#race-ready-checkbox').prop('checked', true);
            }
            return;
        } else {
            globals.spamTimer = now;
        }

        if (this.checked) {
            globals.conn.send('raceReady', {
                'id': globals.currentRaceID,
            });
        } else {
            globals.conn.send('raceUnready', {
                'id': globals.currentRaceID,
            });
        }
    });

    $('#race-quit-button').click(function() {
        if (globals.currentScreen !== 'race') {
            return;
        } else if (globals.raceList.hasOwnProperty(globals.currentRaceID) === false) {
            return;
        } else if (globals.raceList[globals.currentRaceID].status !== 'in progress') {
            return;
        }

        // Find out if we already quit this race
        for (let i = 0; i < globals.raceList[globals.currentRaceID].racerList.length; i++) {
            if (globals.myUsername === globals.raceList[globals.currentRaceID].racerList[i].name) {
                if (globals.raceList[globals.currentRaceID].racerList[i].status !== 'racing') {
                    return;
                }
                break;
            }
        }

        // Don't allow people to spam this
        let now = new Date().getTime();
        if (now - globals.spamTimer < 1000) {
            return;
        } else {
            globals.spamTimer = now;
        }

        globals.conn.send('raceQuit', {
            'id': globals.currentRaceID,
        });
    });

    $('#race-chat-form').submit(function(event) {
        // By default, the form will reload the page, so stop this from happening
        event.preventDefault();

        // Validate input and send the chat
        chat.send('race');
    });
});

/*
    Race functions
*/

const show = function(raceID) {
    // We should be on the lobby screen unless there is severe lag
    if (globals.currentScreen === 'transition') {
        setTimeout(function() {
            show(raceID);
        }, globals.fadeTime + 5); // 5 milliseconds of leeway
        return;
    } else if (globals.currentScreen !== 'waiting-for-server' && globals.currentScreen !== 'lobby') {
        // currentScreen should be "waiting-for-server" if they created a race or joined a current race
        // currentScreen should be "lobby" if they are rejoining a race after a disconnection
        misc.errorShow('Failed to enter the race screen since currentScreen is equal to "' + globals.currentScreen + '".');
        return;
    }
    globals.currentScreen = 'transition';
    globals.currentRaceID = raceID;

    // Put the seed in the clipboard
    if (globals.raceList[globals.currentRaceID].seed !== '-') {
        clipboard.writeText(globals.raceList[globals.currentRaceID].seed);
    }

    // Show and hide some buttons in the header
    $('#header-profile').fadeOut(globals.fadeTime);
    $('#header-leaderboards').fadeOut(globals.fadeTime);
    $('#header-help').fadeOut(globals.fadeTime);
    $('#header-new-race').fadeOut(globals.fadeTime);
    if (globals.raceList[globals.currentRaceID].status === 'in progress') {
        $('#header-lobby').addClass('disabled');
    }
    $('#header-settings').fadeOut(globals.fadeTime, function() {
        $('#header-profile').fadeIn(globals.fadeTime);
        $('#header-leaderboards').fadeIn(globals.fadeTime);
        $('#header-help').fadeIn(globals.fadeTime);
        $('#header-lobby').fadeIn(globals.fadeTime);
    });

    // Close all tooltips
    misc.closeAllTooltips();

    // Show the race screen
    $('#lobby').fadeOut(globals.fadeTime, function() {
        $('#race').fadeIn(globals.fadeTime, function() {
            globals.currentScreen = 'race';
        });

        // Build the title
        let raceTitle;
        if (globals.raceList[globals.currentRaceID].name === '-') {
            raceTitle = 'Race ' + globals.currentRaceID;
        } else {
            // Sanitize the race name
            raceTitle = misc.escapeHtml(globals.raceList[globals.currentRaceID].name);
        }
        if (raceTitle.length > 60) {
            // Truncate the title
            raceTitle = raceTitle.substring(0, 70) + '...';

            // Enable the tooltip
            let content = globals.raceList[globals.currentRaceID].name; // This does not need to be escaped because tooltipster displays HTML as plain text
            $('#race-title').tooltipster('content', content);
        } else {
            // Disable the tooltip
            $('#race-title').tooltipster('content', null);
        }
        $('#race-title').html(raceTitle);

        // Adjust the font size so that it only takes up one line
        let emSize = 1.75; // In HTML5UP Alpha, h3's are 1.75
        while (true) {
            // Reset the font size (we could be coming from a previous race)
            $('#race-title').css('font-size', emSize + 'em');

            // One line is 45 pixels high
            if ($('#race-title').height() > 45) {
                // Reduce the font size by a little bit
                emSize -= 0.1;
            } else {
                break;
            }
        }

        // Column 1 - Status
        let circleClass;
        if (globals.raceList[globals.currentRaceID].status === 'open') {
            circleClass = 'open';
        } else if (globals.raceList[globals.currentRaceID].status === 'starting') {
            circleClass = 'starting';
        } else if (globals.raceList[globals.currentRaceID].status === 'in progress') {
            circleClass = 'in-progress';
        } else if (globals.raceList[globals.currentRaceID].status === 'finished') {
            circleClass = 'finished';
        }
        let statusText = '<span class="circle lobby-current-races-' + circleClass + '"></span> &nbsp; ';
        statusText += '<span lang="en">' + globals.raceList[globals.currentRaceID].status.capitalize() + '</span>';
        $('#race-title-status').html(statusText);

        // Column 2 - Type
        let type = globals.raceList[globals.currentRaceID].ruleset.type;
        $('#race-title-type-icon').css('background-image', 'url("assets/img/type/' + type + '.png")');
        let typeTooltipContent = '<span lang="en">';
        if (type === 'ranked') {
            typeTooltipContent += '<strong><span lang="en">Ranked</span>:</strong><br />';
            typeTooltipContent += '<span lang="en">This race will count towards the leaderboards.</span>';
        } else if (type === 'unranked') {
            typeTooltipContent += '<strong><span lang="en">Unranked</span>:</strong><br />';
            typeTooltipContent += '<span lang="en">This race will not count towards the leaderboards.</span>';
        }
        typeTooltipContent += '</span>';
        $('#race-title-type-icon').tooltipster('content', typeTooltipContent);

        // Column 3 - Format
        let format = globals.raceList[globals.currentRaceID].ruleset.format;
        $('#race-title-format-icon').css('background-image', 'url("assets/img/formats/' + format + '.png")');
        let formatTooltipContent = '<span lang="en">';
        if (format === 'unseeded') {
            formatTooltipContent += '<strong><span lang="en">Unseeded</span>:</strong><br />';
            formatTooltipContent += '<span lang="en">Reset over and over until you find something good from a Treasure Room.</span><br />';
            formatTooltipContent += '<span lang="en">You will be playing on an entirely different seed than your opponent(s).</span>';
        } else if (format === 'seeded') {
            formatTooltipContent += '<strong><span lang="en">Seeded</span>:</strong><br />';
            formatTooltipContent += '<span lang="en">You will play on the same seed as your opponent and start with The Compass.</span>';
        } else if (format === 'diversity') {
            formatTooltipContent += '<strong><span lang="en">Diversity</span>:</strong><br />';
            formatTooltipContent += '<span lang="en">This is the same as the "Unseeded" format, but you will also start with three random passive items.</span><br />';
            formatTooltipContent += '<span lang="en">All players will start with the same three items.</span>';
        } else if (format === 'custom') {
            formatTooltipContent += '<strong><span lang="en">Custom</span>:</strong><br />';
            formatTooltipContent += '<span lang="en">You make the rules! Make sure that everyone in the race knows what to do before you start.</span>';
        }
        formatTooltipContent += '</span>';
        $('#race-title-format-icon').tooltipster('content', formatTooltipContent);

        // Column 4 - Character
        $('#race-title-character').html(globals.raceList[globals.currentRaceID].ruleset.character);

        // Column 5 - Goal
        let goal = globals.raceList[globals.currentRaceID].ruleset.goal;
        $('#race-title-goal-icon').css('background-image', 'url("assets/img/goals/' + goal + '.png")');
        let goalTooltipContent = '<span lang="en">';
        if (goal === 'Blue Baby') {
            goalTooltipContent += 'Defeat Blue Baby (the boss of The Chest) and jump into the chest that falls down afterward.';
        } else if (goal === 'The Lamb') {
            goalTooltipContent += 'Defeat The Lamb (the boss of The Dark Room) and jump into the chest that falls down afterward.';
        } else if (goal === 'Mega Satan') {
            goalTooltipContent += 'Defaut Mega Satan (the boss behind the giant locked door).';
        }
        goalTooltipContent += '</span>';
        $('#race-title-goal-icon').tooltipster('content', goalTooltipContent);

        // Adjust the racer table depending on the format
        if (globals.raceList[globals.currentRaceID].ruleset.format === 'seeded' ||
            globals.raceList[globals.currentRaceID].ruleset.format === 'diversity') {

            $('#race-title-table-seed').fadeIn(0);
            $('#race-title-seed').fadeIn(0);
            $('#race-title-seed').html(globals.raceList[globals.currentRaceID].seed);
        } else {
            $('#race-title-table-seed').fadeOut(0);
            $('#race-title-seed').fadeOut(0);
        }
        if (globals.raceList[globals.currentRaceID].ruleset.format === 'seeded') {
            $('#race-title-table-build').fadeIn(0);
            $('#race-title-build').fadeIn(0);
            $('#race-title-build').html(globals.raceList[globals.currentRaceID].ruleset.startingBuild);
        } else {
            $('#race-title-table-build').fadeOut(0);
            $('#race-title-build').fadeOut(0);
        }

        // Show the pre-start race controls
        $('#race-ready-checkbox-container').fadeIn(0);
        $('#race-ready-checkbox').prop('checked', false);
        $('#race-countdown').fadeOut(0);
        $('#race-quit-button-container').fadeOut(0);
        $('#race-controls-padding').fadeOut(0);
        $('#race-num-left-container').fadeOut(0);

        // Set the race participants table to the pre-game state (with 2 columns)
        $('#race-participants-table-place').fadeOut(0);
        $('#race-participants-table-status').css('width', '70%');
        $('#race-participants-table-floor').fadeOut(0);
        $('#race-participants-table-item').fadeOut(0);
        $('#race-participants-table-time').fadeOut(0);
        $('#race-participants-table-offset').fadeOut(0);

        // Automatically scroll to the bottom of the chat box
        let bottomPixel = $('#race-chat-text').prop('scrollHeight') - $('#race-chat-text').height();
        $('#race-chat-text').scrollTop(bottomPixel);

        // Focus the chat input
        $('#race-chat-box-input').focus();

        // If we disconnected in the middle of the race, we need to update the race controls
        if (globals.raceList[globals.currentRaceID].status === 'starting') {
            misc.errorShow('You rejoined the race during the countdown, which is not supported. Please relaunch the program.');
        } else if (globals.raceList[globals.currentRaceID].status === 'in progress') {
            start();
        }
    });
};
exports.show = show;

// Add a row to the table with the race participants on the race screen
exports.participantAdd = function(i) {
    // Begin building the row
    let racer = globals.raceList[globals.currentRaceID].racerList[i];
    let racerDiv = '<tr id="race-participants-table-' + racer.name + '">';

    // The racer's place
    racerDiv += '<td id="race-participants-table-' + racer.name + '-place" class="hidden">';
    if (racer.place === -1 || racer.place === -2) {
        racerDiv += '-'; // They quit or were disqualified
    } else if (racer.place === 0) { // If they are still racing
        racerDiv += misc.ordinal_suffix_of(racer.placeMid); // This is their non-finished place based on their current floor
    } else {
        // They finished, so mark the place as a different color to distinguish it from a mid-game place
        racerDiv += '<span style="color: blue;">';
        racerDiv += misc.ordinal_suffix_of(racer.place);
        racerDiv += '</span>';
    }
    racerDiv += '</td>';

    // The racer's name
    racerDiv += '<td id="race-participants-table-' + racer.name + '-name">' + racer.name + '</td>';

    // The racer's status
    racerDiv += '<td id="race-participants-table-' + racer.name + '-status">';
    // This will get filled in later in the "participantsSetStatus" function
    racerDiv += '</td>';

    // The racer's floor
    racerDiv += '<td id="race-participants-table-' + racer.name + '-floor" class="hidden">';
    // This will get filled in later in the "participantsSetFloor" function
    racerDiv += '</td>';

    // The racer's starting item
    racerDiv += '<td id="race-participants-table-' + racer.name + '-item" class="hidden">';
    // This will get filled in later in the "participantsSetItem" function
    racerDiv += '</td>';

    // The racer's time
    racerDiv += '<td id="race-participants-table-' + racer.name + '-time" class="hidden">';
    racerDiv += '</td>';

    // The racer's time offset
    racerDiv += '<td id="race-participants-table-' + racer.name + '-offset" class="hidden">-</td>';

    // Append the row
    racerDiv += '</tr>';
    $('#race-participants-table-body').append(racerDiv);

    // To fix a small visual bug where the left border isn't drawn because of the left-most column being hidden
    $('#race-participants-table-' + racer.name + '-name').css('border-left', 'solid 1px #e5e5e5');

    // Update some values in the row
    participantsSetStatus(i, true);
    participantsSetFloor(i);
    participantsSetItem(i);
};

const participantsSetStatus = function(i, initial = false) {
    let racer = globals.raceList[globals.currentRaceID].racerList[i];

    // Update the status column of the row
    let statusDiv = '';
    if (racer.status === 'ready') {
        statusDiv += '<i class="fa fa-check" aria-hidden="true" style="color: green;"></i> &nbsp; ';
    } else if (racer.status === 'not ready') {
        statusDiv += '<i class="fa fa-times" aria-hidden="true" style="color: red;"></i> &nbsp; ';
    } else if (racer.status === 'racing') {
        statusDiv += '<i class="mdi mdi-chevron-double-right" style="color: orange;"></i> &nbsp; ';
    } else if (racer.status === 'quit') {
        statusDiv += '<i class="mdi mdi-skull"></i> &nbsp; ';
    } else if (racer.status === 'finished') {
        statusDiv += '<i class="fa fa-check" aria-hidden="true" style="color: green;"></i> &nbsp; ';
    }
    statusDiv += '<span lang="en">' + racer.status.capitalize() + '</span>';
    $('#race-participants-table-' + racer.name + '-status').html(statusDiv);

    if (racer.status === 'finished') {
        // Update the place column of the row
        let ordinal = misc.ordinal_suffix_of(racer.place);
        let placeDiv = '<span style="color: blue;">' + ordinal + '</span>';
        $('#race-participants-table-' + racer.name + '-place').html(placeDiv);

        // Recalculate everyones mid-race places
        placeMidRecalculateAll();
    } else if (racer.status === 'quit') {
        // Update the place column of the row
        $('#race-participants-table-' + racer.name + '-place').html('-');

        // Recalculate everyones mid-race places
        placeMidRecalculateAll();
    }

    // If we finished, play the sound effect that matches our place
    // (don't play the "1st place" voice for 1 player races)
    if (racer.name === globals.myUsername &&
        racer.status === 'finished' &&
        globals.raceList[globals.currentRaceID].racerList.length > 1) {

        misc.playSound('place/' + racer.place, 1800);
    }

    // If we quit or finished
    if (racer.name === globals.myUsername && (racer.status === 'quit' || racer.status === 'finished')) {
        // Hide the button since we can only quit once
        $('#race-controls-padding').fadeOut(globals.fadeTime);
        $('#race-quit-button-container').fadeOut(globals.fadeTime);
    }

    // Play a sound effect if someone quit or finished
    if (initial === false) {
        if (racer.status === 'finished') {
            misc.playSound('finished');
        } else if (racer.status === 'quit') {
            misc.playSound('quit');
        }
    }

    // Find out the number of people left in the race
    let numLeft = 0;
    for (let i = 0; i < globals.raceList[globals.currentRaceID].racerList.length; i++) {
        let theirStatus = globals.raceList[globals.currentRaceID].racerList[i].status;
        if (theirStatus === 'racing') {
            numLeft++;
        }
    }
    $('#race-num-left').html(numLeft + ' left');
    if (racer.status === 'finished' || racer.status === 'quit' || racer.status === 'disqualified') {
        if (initial === false) {
            globals.log.info('There are', numLeft, 'people left in race:', globals.currentRaceID);
        }
    }
};
exports.participantsSetStatus = participantsSetStatus;

function placeMidRecalculateAll() {
    // Get the current (final) place (it will be 0 if no-one has finished yet)
    let currentPlace = 0;
    for (let i = 0; i < globals.raceList[globals.currentRaceID].racerList.length; i++) {
        if (globals.raceList[globals.currentRaceID].racerList[i].place > currentPlace) {
            currentPlace = globals.raceList[globals.currentRaceID].racerList[i].place;
        }
    }

    // Recalculate everyones mid-race places
    for (let i = 0; i < globals.raceList[globals.currentRaceID].racerList.length; i++) {
        let racer = globals.raceList[globals.currentRaceID].racerList[i];
        if (racer.status !== 'racing') {
            continue;
        }
        racer.placeMid = currentPlace + 1;
        for (let j = 0; j < globals.raceList[globals.currentRaceID].racerList.length; j++) {
            let racer2 = globals.raceList[globals.currentRaceID].racerList[j];
            if (racer2.status !== 'racing') {
                continue;
            }
            if (racer2.floorNum > racer.floorNum) {
                racer.placeMid++;
            } else if (racer2.floorNum == racer.floorNum && racer2.floorArrived < racer.floorArrived) {
                racer.placeMid++;
            }
        }
        globals.raceList[globals.currentRaceID].racerList[i].placeMid = racer.placeMid;
        let ordinal = misc.ordinal_suffix_of(racer.placeMid);
        $('#race-participants-table-' + racer.name + '-place').html(ordinal);
    }
}

const participantsSetFloor = function(i) {
    let name = globals.raceList[globals.currentRaceID].racerList[i].name;
    let floorNum = globals.raceList[globals.currentRaceID].racerList[i].floorNum;
    let stageType = globals.raceList[globals.currentRaceID].racerList[i].stageType;

    // Update the floor column of the row
    let floorDiv;
    if (floorNum === 0) {
        floorDiv = '-';
    } else if (floorNum === 1) {
        floorDiv = 'B1';
    } else if (floorNum === 2) {
        floorDiv = 'B2';
    } else if (floorNum === 3) {
        floorDiv = 'C1';
    } else if (floorNum === 4) {
        floorDiv = 'C2';
    } else if (floorNum === 5) {
        floorDiv = 'D1';
    } else if (floorNum === 6) {
        floorDiv = 'D2';
    } else if (floorNum === 7) {
        floorDiv = 'W1';
    } else if (floorNum === 8) {
        floorDiv = 'W2';
    } else if (floorNum === 9) {
        floorDiv = 'BW';
    } else if (floorNum === 10 && stageType === 0) {
        floorDiv = 'Sheol'; // 10-0 is Sheol
    } else if (floorNum === 10 && stageType === 1) {
        floorDiv = 'Cath'; // 10-1 is Cathedral
    } else if (floorNum === 11 && stageType === 0) {
        floorDiv = 'DR'; // 11-0 is Dark Room
    } else if (floorNum === 11 && stageType === 1) {
        floorDiv = 'Chest';
    } else {
        misc.errorShow('The floor for ' + name + ' is unrecognized: ' + floorNum);
    }
    $('#race-participants-table-' + name + '-floor').html(floorDiv);

    // Recalculate everyones mid-race places
    placeMidRecalculateAll();
};
exports.participantsSetFloor = participantsSetFloor;

const participantsSetItem = function(i) {
    // Go through the array and find the starting item
    let items = globals.raceList[globals.currentRaceID].racerList[i].items;
    let startingItem = false;
    for (let j = 0; j < items.length; j++) {
        if (items[j].id === 105) {
            // Skip the D6
            continue;
        }
        startingItem = items[j].id;
        break;
    }

    // Update the starting item column of the row
    if (startingItem !== false) {
        $('#race-participants-table-' + name + '-item').html(startingItem);
    } else {
        $('#race-participants-table-' + name + '-item').html('-');
    }

};
exports.participantsSetItem = participantsSetItem;

exports.markOnline = function() {
    // TODO
};

exports.markOffline = function() {
    // TODO
};

const startCountdown = function() {
    if (globals.currentScreen === 'transition') {
        // Come back when the current transition finishes
        setTimeout(function() {
            startCountdown();
        }, globals.fadeTime + 5); // 5 milliseconds of leeway
        return;
    }

    // Don't do anything if we are not on the race screen
    if (globals.currentScreen !== 'race') {
        return;
    }

    // Change the functionality of the "Lobby" button in the header
    $('#header-lobby').addClass('disabled');

    // Play the "Let's Go" sound effect
    misc.playSound('lets-go');

    // Show the countdown
    $('#race-ready-checkbox-container').fadeOut(globals.fadeTime, function() {
        $('#race-countdown').css('font-size', '1.75em');
        $('#race-countdown').css('bottom', '0.25em');
        $('#race-countdown').css('color', '#e89980');
        $('#race-countdown').html('<span lang="en">Race starting in 10 seconds!</span>');
        $('#race-countdown').fadeIn(globals.fadeTime);
    });
};
exports.startCountdown = startCountdown;

const countdownTick = function(i) {
    if (globals.currentScreen === 'transition') {
        // Come back when the current transition finishes
        setTimeout(function() {
            countdownTick();
        }, globals.fadeTime + 5); // 5 milliseconds of leeway
        return;
    }

    // Don't do anything if we are not on the race screen
    if (globals.currentScreen !== 'race') {
        return;
    }

    if (i > 0) {
        $('#race-countdown').fadeOut(globals.fadeTime, function() {
            $('#race-countdown').css('font-size', '2.5em');
            $('#race-countdown').css('bottom', '0.375em');
            $('#race-countdown').css('color', 'red');
            $('#race-countdown').html(i);
            $('#race-countdown').fadeIn(globals.fadeTime);
            setTimeout(function() {
                // Focus the game with 3 seconds remaining on the countdown
                if (i === 3) {
                    let command = path.join(__dirname, '/assets/programs/isaacFocus/isaacFocus.exe');
                    execFile(command);
                }

                // Play the sound effect associated with the final 3 seconds
                if (i === 3 || i === 2 || i === 1) {
                    misc.playSound(i);
                }
            }, globals.fadeTime / 2);
        });

        setTimeout(function() {
            countdownTick(i - 1);
        }, 1000);
    }
};
exports.countdownTick = countdownTick;

const go = function(raceID) {
    if (globals.currentScreen === 'transition') {
        // Come back when the current transition finishes
        setTimeout(function() {
            go();
        }, globals.fadeTime + 5); // 5 milliseconds of leeway
        return;
    }

    // Don't do anything if we are not on the race screen or we are in a different race
    if (globals.currentScreen !== 'race' || globals.currentRaceID !== raceID) {
        return;
    }

    $('#race-countdown').html('<span lang="en">Go!</span>');
    $('#race-title-status').html('<span class="circle lobby-current-races-in-progress"></span> &nbsp; <span lang="en">In Progress</span>');

    // Press enter inside of the game
    /*let command = path.join(__dirname, '/assets/programs/raceGo/raceGo.exe');
    execFile(command);*/

    // Play the "Go" sound effect
    misc.playSound('go');

    // Wait 4 seconds, then start to change the controls
    setTimeout(start, 4000);

    // Add default values to the columns to the race participants table (defaults)
    for (let i = 0; i < globals.raceList[globals.currentRaceID].racerList.length; i++) {
        globals.raceList[globals.currentRaceID].racerList[i].status = 'racing';
        globals.raceList[globals.currentRaceID].racerList[i].place = 0;
        globals.raceList[globals.currentRaceID].racerList[i].placeMid = 1;

        let racerName = globals.raceList[globals.currentRaceID].racerList[i].name;
        let statusDiv = '<i class="mdi mdi-chevron-double-right" style="color: orange;"></i> &nbsp; <span lang="en">Racing</span>';
        $('#race-participants-table-' + racerName + '-status').html(statusDiv);
        $('#race-participants-table-' + racerName + '-item').html('-');
        $('#race-participants-table-' + racerName + '-time').html('-');
        $('#race-participants-table-' + racerName + '-offset').html('-');
    }
};
exports.go = go;

const start = function() {
    // Don't do anything if we are not on the race screen
    // (it is okay to proceed here if we are on the transition screen since we want the race controls to be drawn before it fades in)
    if (globals.currentScreen !== 'race' && globals.currentScreen !== 'transition') {
        return;
    }

    // In case we coming back after a disconnect, redo all of the stuff that was done in the "startCountdown" function
    $('#race-ready-checkbox-container').fadeOut(0);

    // Start the race timer
    setTimeout(raceTimerTick, 0);

    // Change the controls on the race screen
    $('#race-countdown').fadeOut(globals.fadeTime, function() {
        // Find out if we have quit or finished this race already and count the number of people who are still in the race
        // (which should be everyone, but just in case)
        let alreadyFinished = false;
        let numLeft = 0;
        for (let i = 0; i < globals.raceList[globals.currentRaceID].racerList.length; i++) {
            let racer = globals.raceList[globals.currentRaceID].racerList[i];
            if (racer.name === globals.myUsername &&
                (racer.status === 'quit' || racer.status === 'finished')) {

                alreadyFinished = true;
            }
            if (racer.status === 'racing') {
                numLeft++;
            }
        }

        // Show the quit button
        if (alreadyFinished === false) {
            $('#race-quit-button-container').fadeIn(globals.fadeTime);
            $('#race-controls-padding').fadeIn(globals.fadeTime);
        }

        // Show the number of people left in the race
        $('#race-num-left').html(numLeft + ' left');
        $('#race-num-left-container').fadeIn(globals.fadeTime);
    });

    // Change the table to have 6 columns instead of 2
    $('#race-participants-table-place').fadeIn(globals.fadeTime);
    $('#race-participants-table-status').css('width', '7.5em');
    $('#race-participants-table-floor').fadeIn(globals.fadeTime);
    $('#race-participants-table-item').fadeIn(globals.fadeTime);
    $('#race-participants-table-time').fadeIn(globals.fadeTime);
    $('#race-participants-table-offset').fadeIn(globals.fadeTime);
    for (let i = 0; i < globals.raceList[globals.currentRaceID].racerList.length; i++) {
        let racer = globals.raceList[globals.currentRaceID].racerList[i].name;
        $('#race-participants-table-' + racer + '-place').fadeIn(globals.fadeTime);
        $('#race-participants-table-' + racer.name + '-name').css('border-left', '0'); // To fix a small visual bug where the left border isn't drawn because of the left-most column being hidden
        $('#race-participants-table-' + racer + '-floor').fadeIn(globals.fadeTime);
        $('#race-participants-table-' + racer + '-item').fadeIn(globals.fadeTime);
        $('#race-participants-table-' + racer + '-time').fadeIn(globals.fadeTime);
        $('#race-participants-table-' + racer + '-offset').fadeIn(globals.fadeTime);
    }
};
exports.start = start;

function raceTimerTick() {
    // Don't do anything if we are not on the race screen
    // (we can also be on the transition screen if we are reconnecting in the middle of a race)
    if (globals.currentScreen !== 'race' && globals.currentScreen !== 'transition') {
        return;
    }

    // Stop the timer if the race is over
    // (the race is over if the entry in the raceList is deleted)
    if (globals.raceList.hasOwnProperty(globals.currentRaceID) === false) {
        return;
    }

    // Get the elapsed time in the race
    let now = new Date().getTime();
    let raceMilliseconds = now - globals.raceList[globals.currentRaceID].datetimeStarted + globals.timeOffset;
    let raceSeconds = Math.round(raceMilliseconds / 1000);
    let timeDiv = misc.pad(parseInt(raceSeconds / 60, 10)) + ':' + misc.pad(raceSeconds % 60);

    // Update all of the timers
    for (let i = 0; i < globals.raceList[globals.currentRaceID].racerList.length; i++) {
        if (globals.raceList[globals.currentRaceID].racerList[i].status === 'racing') {
            $('#race-participants-table-' + globals.raceList[globals.currentRaceID].racerList[i].name + '-time').html(timeDiv);
        }
    }

    // Schedule the next tick
    setTimeout(raceTimerTick, 1000);
}