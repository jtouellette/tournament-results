#!/usr/bin/env python
#
# tournament.py -- implementation of a Swiss-system tournament
#

import psycopg2


def connect(caller=None):

    """ Connect to the PostgreSQL database.  Returns a database connection and cursor.
        Args:
            caller: Optional name of the calling function to print in error handling.
    """

    try:
        DB = psycopg2.connect("dbname=tournament")
        cursor = DB.cursor()
    except Exception as e:
        if caller:
            "\t{caller}: Unable to establish database connection!".format(caller=caller.upper())
        else:
            "\tCONNECT: Unable to establish database connection!"
        print "\t", e
        return None, None

    return DB, cursor

def deleteTournaments():

    """ Delets all tournaments.  To prevent any orphaned entries, the contents of MATCHES and PLAYERS are emptied as well. """

    (DB, cursor) = connect(caller="DELETE TOURNAMENTS")

    if DB:
        try:
            cursor.execute('DELETE FROM matches')
            cursor.execute('DELETE FROM players')
            cursor.execute('DELETE FROM tournaments')
            DB.commit()

            cursor.close()
            DB.close()

            print "\tDELETE TOURNAMENTS: Successfully deleted all tournaments."

        except Exception as e:
            print "\tDELETE TOURNAMENTS: Unable to delete tournaments."
            print "\t", e

def createTournament(name, set_as_current=True):

    """ Creates a new tournament.
        Args:
            name: The desired name for the tournament.
            set_as_current: If TRUE, the new tournament will be made the current tournament.
    """

    (DB, cursor) = connect(caller="CREATE TOURNAMENT")

    if DB:
        try:
            cursor.execute('INSERT INTO tournaments (id, name) VALUES (DEFAULT, %s) RETURNING id', (name, ))
            created_id = cursor.fetchone()[0]
            DB.commit()

            if set_as_current:
                setCurrentTournament(id=created_id)

            cursor.close()
            DB.close()

            print "\tCREATE TOURNAMENT: Successfully created the tournament '{n}'.".format(n=name)
        except Exception as e:
            print "\tCREATE TOURNAMENT: Unable to create tournament."
            print "\t", e

        return created_id
    return None

def setCurrentTournament(id):

    """ Sets the current tournament for the database to be using.
        Args:
            id: The ID of the tournament to use as the default.
    """

    (DB, cursor) = connect(caller="SET CURRENT TOURNAMENT")

    if DB:
        try:
            cursor.execute('SELECT set_current_tournament_id(%s)',(id, ))
            DB.commit()

            cursor.close()
            DB.close()

            print "\tSET CURRENT TOURNAMENT: Set the current tournament to #{num}.".format(num=id)
        except Exception as e:
            print "\tSET CURRENT TOURNAMENT: Unable to set the current tournament!"
            print "\t", e

def countTournaments():

    """ Counts the number of tournaments in the database and returns it as an integer. """

    (DB, cursor) = connect(caller="COUNT TOURNAMENTS")

    if DB:
        try:
            cursor.execute('SELECT count(*) FROM tournaments;')

            number_of_tournaments = cursor.fetchone()[0]

            print "\tCOUNT TOURNAMENTS: Found {num} tournaments.".format(num=number_of_tournaments)

            cursor.close()
            DB.close()

            return number_of_tournaments
        except Exception as e:
            print "\tCOUNT TOURNAMENTS: Unable to count tournaments."
            print "\t", e
            return None


def deleteMatches(only_current_tournament=True):

    """ Remove all the match records from the database.
            Args:
                only_current_tournament: If TRUE, only delete matches from the current tournament, or FALSE to delete from all tournaments.
    """

    (DB, cursor) = connect(caller="DELETE MATCHES")

    if DB:
        try:
            if only_current_tournament:
                cursor.execute('DELETE FROM matches WHERE tournament = get_current_tournament_id();')
            else:
                cursos.execute('DELETE FROM matches;')
            DB.commit()
            cursor.close()
            DB.close()
        except Exception as e:
            print "\tDELETE MATCHES: Unable to delete all players!"
            print "\t", e
            return

    print('\tDELETE MATCHES: Successfully deleted all matches.')

def deletePlayers(only_current_tournament=True):

    """ Remove all the player records from the database.
            Args:
                only_current_tournament: If TRUE, only delete players from the current tournament, or FALSE to delete from all tournaments.
        """

    (DB, cursor) = connect(caller="COUNT TOURNAMENTS")

    if DB:
        try:
            if only_current_tournament:
                cursor.execute('DELETE FROM players WHERE tournament = get_current_tournament_id();')
            else:
                cursor.execute('DELETE FROM players;')
            DB.commit()
            cursor.close()
            DB.close()

        except Exception as e:
            print "\tDELETE PLAYERS: Unable to delete all players!"
            print "\t", e
            return

    print('\tDELETE PLAYERS: Successfully deleted all players.')


def countPlayers(only_current_tournament=True):

    """ Returns the number of players currently registered.
        Args:
            only_current_tournament: TRUE to count only from the current tournament, or FALSE to count from all tournaments.
    """

    (DB, cursor) = connect(caller="COUNT PLAYERS")

    if DB:
        try:
            if only_current_tournament:
                cursor.execute('SELECT count(*) AS number_of_players FROM players WHERE tournament = get_current_tournament_id();')
            else:
                cursor.execute('SELECT count(*) AS number_of_players FROM players')
            number_of_players = cursor.fetchone()[0]

            print "\tCOUNT PLAYERS: Found {count} players.".format(count=number_of_players)

            cursor.close()
            DB.close()

            return int(number_of_players)

        except Exception as e:
            print "\tCOUNT PLAYERS: Unable to count the number of players!"
            print "\t", e
            return 0

def registerPlayer(name, tournament_id=-1):

    """ Adds a player to the tournament database.

    The database assigns a unique serial id number for the player.  (This
    should be handled by your SQL database schema, not in your Python code.)

    Args:
      name: The player's full name (need not be unique).
      tournament_id: The tournament to register the player for. The default value of  -1 will assign them to
                     the current tournament.
    """

    (DB, cursor) = connect(caller="COUNT PLAYERS")

    if DB:
        try:
            if tournament_id == -1:
                cursor.execute('INSERT INTO players (name, tournament) VALUES (%s, DEFAULT) RETURNING id;', (name, ))
            else:
                cursor.execute('INSERT INTO players (name, tournament) VALUES (%s, %s) RETURNING id;', (name, tournament_id))

            id_of_new_row = cursor.fetchone()[0]

            DB.commit()

            #cursor.execute('SELECT LASTVAL()')
            #id_of_new_row = cursor.fetchone()[0]

            cursor.close()
            DB.close()

            print "\tRESISTER PLAYER: '{name}' was succesfully added as player {id}.".format(name=name, id=id_of_new_row)

        except Exception as e:
            print "\tREGISTER PLAERY: An error occured trying to create a player named {name}!".format(name=name)
            print "\t", e

        return id_of_new_row
    else:
        return None

def playerStandings():
    """Returns a list of the players and their win records, sorted by wins.

    The first entry in the list should be the player in first place, or a player
    tied for first place if there is currently a tie.

    Returns:
      A list of tuples, each of which contains (id, name, wins, matches):
        id: the player's uniqute id (assigned by the database)
        name: the player's full name (as registered)
        wins: the number of matches the player has won
        matches: the number of matches the player has played
    """

    (DB, cursor) = connect(caller="COUNT PLAYERS")

    if DB:
        try:
            standings_list = []

            cursor.execute('SELECT * FROM standings;')

            for player in cursor.fetchall():
                standings_list.append((int(player[0]), player[1], int(player[3]), int(player[2])))

            print '\tPLAYER STANDINGS: ', standings_list

            cursor.close()
            DB.close()

            return standings_list

        except Exception as e:
            print "\tPLAYER STANDINGS: Unable to generate a list of player standings!"
            print "\t", e
            return None

def reportMatch(player_a, player_b, winner=None, tournament_id=-1):
    """Records the outcome of a single match between two players.

    Args:
      player_a:  the id number of the first player
      player_b:  the id number of the second player. The order of player_a and player_b does not matter.
      winner: the id number of the player who won, matching player_a or player_b.  Leave empty for a tie.
      tournament_id: the id number of the tournament for which the match was played. The default of -1 will
                     record to the current tournament.
    """
    (DB, cursor) = connect(caller="REPORT MATCH")

    if DB:
        try:
            if winner and winner in [player_a, player_b]:
                if tournament_id == -1:
                    cursor.execute('INSERT INTO matches (player_a, player_b, winner) VALUES (%s, %s, %s)',
                                    (player_a, player_b, winner))
                else:
                    cursor.execute('INSERT INTO matches (player_a, player_b, winner, tournament) VALUES (%s, %s, %s, %s)',
                                    (player_a, player_b, winner, tournament_id))
            elif winner:
                print '\tREPORT MATCH: You have provided an invalid winner ({w}) for a match between'\
                      ' players {pa} and {pb}!'.format(w=winner, pa=player_a, pb=player_b)
                return
            else:
                if tournament_id == -1:
                    cursor.execute('INSERT INTO matches (player_a, player_b) VALUES (%s, %s)',
                                   (player_a, player_b))
                else:
                    cursor.execute('INSERT INTO matches (player_a, player_b, tournament) VALUES (%s, %s, %s)',
                                   (palyer_a, player_b, tournament_id))

            DB.commit()
            cursor.close()
            DB.close()

            print "\tREPORT MATCH: Successfully created a match between players {pa} and {pb}.".format(pa=player_a,
                                                                                                       pb=player_b)

        except Exception as e:
            print "\tREPORT MATCH: An error occured trying to create a match between players {pa} and {pb}!".format(pa=player_a,
                                                                                                                    pb=player_b)

def swissPairings():
    """Returns a list of pairs of players for the next round of a match.

    Assuming that there are an even number of players registered, each player
    appears exactly once in the pairings.  Each player is paired with another
    player with an equal or nearly-equal win record, that is, a player adjacent
    to him or her in the standings.

    Returns:
      A list of tuples, each of which contains (id1, name1, id2, name2)
        id1: the first player's unique id
        name1: the first player's name
        id2: the second player's unique id
        name2: the second player's name
    """
    (DB, cursor) = connect(caller="SWISS PAIRINGS")

    if DB:
        try:
            cursor.execute('SELECT * FROM next_round_matchups;')

            matchups = []
            for matchup in cursor.fetchall():
                new_matchup = (matchup[1], matchup[2], matchup[3], matchup[4])
                matchups.append(new_matchup)

            print "\tSWISS PAIRINGS: ", matchups

            cursor.close()
            DB.close

            return matchups
        except Exception as e:
            print "\tSWISS PAIRINGS: Unable to generate swiss pairings."
            print "\t", e
            return

if __name__ == '__main__':

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
