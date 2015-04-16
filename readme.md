# Tournament Results Documentation

## I. Installation and Basic Use

#### Step One: Setup the database in Postgres.

In your command line, move the folder containing *tournament.sql*.  You may run the file in your terminal by typing ```psql -f tournament.sql``` or by starting the Postgres command line by typing ```psql``` and issuing the command ```\i tournament.sql```.  When complete, exit Postgres with ```\q```.

#### Step Two: Running the test profile.

From your command line, you may run the test profile by entering the command ```python tournament_test.py```.

## II. About the Database

The database is setup to handle the following features:

* Multiple Tournaments
* Opponent Match Wins (OMW) Tie-Breaking
* Support for Tied Matches

### Schema - Tables

Table | Meaning
------|---------
tournaments | List of the tournaments in the database. One may be designated at the current tournament.
players | List of players registered for all tournaments and which tournament they are registered for.
matches | List of matches between two players, and which, if either, won the match.

##### Table "tournaments"

Column | Type | Meaning
-------|------|--------
id     | SERIAL | Unique identified to serve as the primary key.
name   | VARCHAR(255) | Name of the tournament. May not be blank.  Example: 'Udacity World Finals'.
is_current | BOOLEAN | Various views refer to the current tournament only.  Setting this value to TRUE makes this entry to current tournament.  There should only ever be one current tournament at a time.  See ```set_current_tournament_id()``` for a function that enforces that rule.

##### Table "players"

Column | Type | Meaning
-------|------|--------
id 	   | SERIAL | Unique identifier to serve as the primary key.
name   | VARCHAR(255) | Name of the player. May not be blank. Example: 'Joshua Ouellette'.
tournament | INTEGER | References an ID from TOURNAMENTS for the tournament the player is registered for.  If no value is provided, it will default to the current tournament.

##### Table "matches"

Column | Type | Meaning
-------|------|--------
id     | SERIAL | Unique identifier to serve as the primary key.
player_a | INT  | References an ID from PLAYERS to represent the first player in the match.
player_b | INT  | References an ID from PLAYERS to represent the second player in the match.
winner   | INT  | The ID of the player who won the match. Must match PLAYER_A, PLAYER_B or be blank for a tie/draw.
tournmanet | INT | References and ID from TOURNAMENTS to represent which tournament the match was played in.

### Schema - Views

There are a series of views only used as intermediate steps in generating other views.  They are not document here but are described in ```tournament.sql```.  They include:

- **current_tournament_players**: Selects only the players that are registered for the current tournament.
- **current_tournament_matches**: Selects only the matches that were played in the current tournament.
- **individual_outcomes**: Converts the player_a vs. player_b format of MATCHES into a list of wins, losses, or ties for each player.
- **individual_wins**: Counts the number of wins for each player in the current tournament.
- **complete_records**: Generates a table of each player, their total matches, and their number of wins.
- **round_placement**: A list of the players in the current tournament sorted by number of wins, followed by OMW.  Used to created numbered ranks (1st, 2nd, etc.).
- **even_placements**: Just those players who's current standing is an even number (2nd, 4th, etc.).
- **odd_placements**: Just those players who's current standing is an odd number (1st, 3rd, etc.).

These views are intended to be accessed directly by the user or Python script:

#### View "standings"

STANDINGS is meant to provide the current state of the tournament, including each player's record and relative position.

Column | Type | Sort | Meaning
-------|------|------|--------
id     | INT| |      | References the player's unique PLAYERS.ID.
name   | VARCHAR(255) | | Name of player found in PLAYERS.NAME.
matches | INT | | Number of matches played by that player.
wins    | INT | DESC (1st) | Number of wins recorded for that player.
omw     | INT | DESC (2nd) | Opponent Match Wins -- total number of wins recorded for all oppoents this player has faced.

#### View "next_round_matchups"

NEXT_ROUND_MATCHUPS provides the next series of matchups based on the current tournament standings.  Odd-positioned players in 1st, 3rd, 5th places etc are always selected as PLAYER_A, while even positioned players are selected as PLAYER_B.

Column | Type | Sort | Meaning
-------|------|------|---------
match  | INT  | ASC  | Match number in the next round, counting up from 1 to N.
player_a_id | INT |  | References PLAYERS.ID for the odd-positioned player.
player_a_name | VARCHAR(255) | | References PLAYERS.NAME for the odd-positioned player.
player_b_id | INT | |  References PLAYERS.ID for the even-positioned player.
player_b_name | VARCHAR(255) | | References PLAYERS.NAME for the even-positioned player.

### Schema - Functions

#### Function "get_current_tournament_id()"

Returns an integer representing the TOURNAMENTS.ID of the currently active tournament, or an empty record if one is not found.  There should only ever been one active tournmanet at a time (see "set_current_tournament_id()"), but if there are one or more inadvertantly, only the first one found is returned.  This may result in odd behaviors, so it is important to use "set_current_tournmanet_id()" to ensure consistency.

#### Function "set_current_tournament_id(INT)"

Accepts an INT value representing the TOURNAMENTS.ID of the tournament to make the currently active tournament.  The TOURNAMENTS.IS_CURRENT value of all tournaments are set to FALSE before the tournament with the matching ID is set to TRUE.  Since TOURNAMENTS.ID enforces unqiue values, one only tournament can have IS_CURRENT set to TRUE by this function.  Always call this function before calling STANDINGS or NEXT_ROUND_MATCHUPS.

## III. About Tournament.py

Tournament.py contains the python scripts used to communicate with the Postgres database. It consists of the following functions:

Function | Parameters | Returns | Description
---------|------------|---------|------------
**connect(caller=*None*)** | **caller (string)**: Optional string name of the calling function. | (DB, cursor) | Establishes a database connection and generates a corresponding cursor, returning the two as a tupple.  If connecting to the database fails, exception information is printed to the console.  **Caller** is an optional parameter consisting of the name of the function from which **connect()** was called to aid in debugging.
**countTournaments()** | none | Integer | Returns an integer count for the total number of tournaments created.
**createTournament(name, set_as_current=*True*)** | **name (string):** The desired name of the tournament </br> set_as_current (boolean): If TRUE, the newly created tournament will also be assigned as the currently active tournament. | Integer id of new tournament. | Creates a new tournament with a name matching the **name** parameter.  Unless specified otherwise by setting **set_as_current** to FALSE, this tournament will also become the active tournament.
**deleteMatches(only_current_tournament=*True*)** | **only_current_tournament (boolean):** TRUE to only delete matches from the current tournament, else delete all tournaments. | nothing | Deletes all matches from the tournament if **only_current_tournament** is TRUE, otherwise, deletes all matches from all tournaments.
**deleteTournaments()** | none | nothing | Removes all tournaments and their associated child data from the database.  This means player and match data is erased as well.
**setCurrentTournament(id)** | **id (int)**: ID of the tournament to set as the current tournament. | nothing | Sets the tournament matching **id** as the current tournament.  All others are set to be inactive tournaments.  If no tournament matches **id**, no current tournament will be selected. *Identifying which tournament is in use is handled by Postgres and not python! It is absolutely necessary to use this function to set a current tournament before any other functionality is available!*
**deletePlayers(only_current_tournament=*True*)** | **only_current_tournament (boolean):** TRUE to only delete matches from the current tournament, else delete all players from all tournaments. | nothing | Deletes all players from the current tournmanet if **only_current_tournament** is TRUE, otherwise delete all players from all tournaments.
**countPlayers(only_current_tournament=*True*)** | **only_current_tournament (boolean):** TRUE to count players only from the current tournament, or FALSE to count from all tournaments. | Integer | Returns the number of players registered for the current tournament or from all tournaments depending on the value of **only_current_tournament**.
**registerPlayer(name, tournament_id=*-1*)** | **name (string):** The name of the player to register. </br> **tournament_id (integer):** The ID of the tournament to register the player for. If left to the default of -1, they will be registered for the current tournament. | nothing | Register a player for a specific tournament.
**playerStandings()** | none | [(id, name, wins, matches),...] | Returns a list of tupples with each player's record for the *current* tournament.
**swissPairings()** | none | [(id_1, name_1, id_2, name_2),...] | Returns a list of tupples with the next round matchups for the *current* tournament.

## IV. Basic Usage Example

This example will create two tournaments, add players to each, record matches, and display the resulting standings and next-round swiss pairings.  You can run it directly by running ```python tournament.py```.

```
    print 'BASIC USAGE EXAMPLE:'

    # Delete all tournaments.

    deleteTournaments()

    # Create two tournaments, one named "Tournament A" and one named "Tournament B".  When Tournament A is created, it will not
    # be made the current tournament. Tournament B will.  Each call returns the ID of the created tournament for future use.

    tournament_a = createTournament('Tournament A', set_as_current=False)
    tournament_b = createTournament('Tournament B')

    # Create two players, "Player 1" and "Player 2" and assign them to the current tournament, which will be Tournament B. Again,
    # the ID of each player is returned so we can reference them later in this example.

    p1 = registerPlayer('Player 1')
    p2 = registerPlayer('Player 2')

    # Create two more players, but rather than register them for the current tournament, specifically register them to
    # Tournament A by using its ID as a parameter.

    p3 = registerPlayer('Not Current A', tournament_id=tournament_a)
    p4 = registerPlayer('Not Current B', tournament_id=tournament_a)

    # Let's switch the current tournament to Tournament A and report a match between Player 3 and Player 4 where Player 3
    # was the winner.

    setCurrentTournament(id=tournament_a)
    reportMatch(player_a=p3, player_b=p4, winner=p3)

    # Now, without changing the current tournament, let's add a match between Players 1 and 2 where Player 1 was the winner,
    # but assign this match manually to Tournament B.

    reportMatch(player_a=p1, player_b=p2, winner=p1, tournament_id=tournament_b)

    # We can verify the results by printing the player standings and swiss pairings for both tournaments.  These functions
    # only work for the current tournament, so we will start by printing the results for Tournament A which is the
    # current tournament.

    print playerStandings()
    print swissPairings()

    # Now, let's switch to Tournament B and print its results as well.

    setCurrentTournament(id=tournament_b)
    print playerStandings()
    print swissPairings()
  ```

