-- Table definitions for the tournament project.

-- ***************************************************************************************************************************
-- DROP FUNCTIONS
-- ***************************************************************************************************************************

-- Uncomment these functions to clear out the database so that you can redefine all of the views, if you choose.  The DROP
-- DATABASE function is sufficient by itself.  The other options are there to give you more control if you don't want to
-- delete everything.  Keep in mind that these commands cascade through all views, so all of them will get reset.

DROP DATABASE IF EXISTS tournament;

-- DROP VIEW IF EXISTS individual_outcomes CASCADE;
-- DROP TABLE IF EXISTS players CASCADE;
-- DROP TABLE IF EXISTS matches CASCADE;
-- DROP TABLE IF EXISTS tournaments CASCADE;

CREATE DATABASE tournament;

\connect tournament;

-- ***************************************************************************************************************************
-- FUNCTIONS
-- ***************************************************************************************************************************


-- GET_CURRENT_TOURNAMENT_ID()
-- ***************************

-- Searches through the TOURNAMENTS table and returns the ID of the first tournament where IS_CURRENT is TRUE.  This represents
-- the current tournament that all of the other functions refer to.  In principle, there should only ever be one tournament
-- matching this query.  To ensure that is the case, use the SET_CURRENT_TOURNAMENT function which enforces that requirement
-- rather than setting a current tournament directly.

CREATE OR REPLACE FUNCTION get_current_tournament_id() RETURNS INTEGER AS $$
DECLARE
	out_id INTEGER;
BEGIN
	SELECT id INTO out_id FROM tournaments WHERE is_current = TRUE ORDER BY id ASC LIMIT 1;
	return out_id;
END;
$$ LANGUAGE plpgsql;


-- SET_CURRENT_TOURNAMENT_ID(int)
-- ******************************

-- Takes an integer representing the ID of the tournament to set at the current tournament.  Sets all tournaments to NOT be
-- the current tournament in order to enforce that only one is has IS_CURRENT set to TRUE.  If the ID is not valid for any
-- tournament, there will be no resulting current tournament.


CREATE OR REPLACE FUNCTION set_current_tournament_id(int) RETURNS BOOLEAN AS $$
BEGIN
	UPDATE tournaments SET is_current = FALSE WHERE TRUE;
	UPDATE tournaments SET is_current = TRUE WHERE id=$1;
	RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- OPPONENT_MATCH_WINS(int)
-- ************************

-- Takes as a parameter the ID of a player and returns an integer representing the number of wins their opponents have acquired,
-- their OMW.  It first generates a list of opponents, then checks each opponent's win record.  I know... not terribly efficient.

CREATE OR REPLACE FUNCTION opponent_match_wins(player_id int) RETURNS INTEGER AS $$
DECLARE
	one_opponent RECORD;
	single_opponent_wins RECORD;
	omw INTEGER;
BEGIN
	omw := 0;

	FOR one_opponent IN
		SELECT CASE WHEN player_a = player_id THEN player_b ELSE player_a END AS id
		FROM matches
		WHERE player_a = player_id
		OR player_b = player_id
		AND tournament = get_current_tournament_id()
	LOOP
		FOR single_opponent_wins IN SELECT count(*) AS wins
									FROM individual_outcomes
									WHERE player = one_opponent.id AND "w/l/t" = 'w'
									LIMIT 1
			LOOP
				omw := omw + single_opponent_wins.wins;
			END LOOP;
	END LOOP;

	RETURN omw;
END;
$$ LANGUAGE plpgsql;

-- ***************************************************************************************************************************
-- TABLES
-- ***************************************************************************************************************************


-- TOURNAMENTS TABLE
-- *****************
-- List of available tournaments with up to one being identified as the current tournament.

-- Example:
-- id |        name       | is_current
-- ---+-------------------+-----------
-- 1  | Sample Tournmanet | t 			<- This would be the current tournmanet.
-- 2  | Fake Championship | f

CREATE TABLE tournaments (
	id SERIAL PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	is_current BOOLEAN DEFAULT FALSE
);



-- PLAYERS TABLE
-- *************
-- Records each players name, the tournament they are registered for and an automatically generated ID for use as a
-- primary key.

-- Example:
--  id  |   name    | tournament
-- -----+-----------+-----------
--  142 | Example 1 | 1
--  143 | Example 2 | 1
--  144 | Example 3 | 1
--  145 | Example 4 | 1
--  146 | Example 5 | 1

CREATE TABLE players (
 	id SERIAL PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	tournament INT references tournaments(id) NOT NULL DEFAULT get_current_tournament_id()
 );


-- MATCHES TABLE
-- **************
-- For each match, general a unique ID and record each of the player by their ID.  If there was a winner,
-- the outcome is stored in WINNER by their player ID.  In the case of a tied match, winner may be left NULL.

-- Example:
--  id | player_a | player_b | winner | tournament
-- ----+----------+----------+--------+-----------
--  32 |      142 |      143 |    142 | 1
--  33 |      144 |      145 |    145 | 1
--  34 |      142 |      145 |    145 | 1
--  37 |      146 |      143 |        | 1            <- Empty winner value denotes a tied match. There is no winner.
--  38 |      146 |      144 |    144 | 1

CREATE TABLE matches (
	id SERIAL PRIMARY KEY NOT NULL,
 	player_a INT references players(id) NOT NULL,
 	player_b INT references players(id) NOT NULL,
 	winner INT references players(id),
 	tournament INT references tournaments(id) NOT NULL DEFAULT get_current_tournament_id()
);


-- ***************************************************************************************************************************
-- VIEWS
-- ***************************************************************************************************************************

-- CURRENT TOURNAMENT PLAYERS
-- **************************
-- Down-selects the PLAYERS table to only those players involved in the current tournament.

-- <<<IMPORTANT>>> ALL OF THE THE SUBSEQUENT VIEWS REFERENCING PLAYERS USE THIS VIEW! EVEN
-- THOUGH THEY ARE NOT OBVIOUSLY SELECTING FOR THE CURRENT TOURNMANET, THEY IN FACT ARE
-- BECAUSE THAT FUNCTION WAS CARRIED OUT HERE.

CREATE VIEW current_tournament_players AS
	SELECT *
	FROM players
	WHERE tournament = get_current_tournament_id();


-- CURRENT TOURNAMENT MATCHES
-- **************************
-- Down-selects the MATCHES table to only those matches from the current tournmanet.

-- <<<IMPORTANT>>> ALL OF THE SUBSEQUENT VIEWS REFERNCING MATCHES USE THIS VIEW! EVEN
-- THOUGH THEY ARE NOT OBVIOUSLY SELECTING FOR THE CURRENT TOURNAMENT, THEY IN FACT ARE
-- BECAUSE TAHT FUNCTION WAS CARRIER OUT HERE.

CREATE VIEW current_tournament_matches AS
	SELECT *
	FROM matches
	WHERE tournament = get_current_tournament_id();


-- INDIVIDUAL_OUTCOMES VIEW
-- ************************
-- Transforms the MATCHES table into a view with two columns. For every MATCH, there will be an entry
-- for each player paired with the result of that match for that player as either a (w)in, (l)oss,
-- or (t)ie.

-- Example: In this case, player 1 beat 2, and 3 beat 4 in one round of play.
--  player | w/l/t
-- --------+-------
--       1 | w
--       2 | l
--       3 | w
--       4 | l

CREATE VIEW individual_outcomes AS
	SELECT player_a AS player,
		CASE
			WHEN winner = player_a THEN 'w'
			WHEN winner = player_b THEN 'l'
			ELSE 't'
		END AS "w/l/t"
	FROM current_tournament_matches
	UNION ALL
	SELECT player_b AS player,
		CASE
			WHEN winner = player_b THEN 'w'
			WHEN winner = player_a THEN 'l'
			ELSE 't'
		END AS "w/l/t"
	FROM current_tournament_matches
	ORDER BY player;



-- INDIVIDUAL_WINS VIEW
-- ********************
-- Returns a table of each player by ID and the number of matches they have won (NUM_WINS).

-- Example:
--  player | num_wins
-- --------+----------
--       1 |        1
--       3 |        1

-- Note that players 2 and 4 are absent because they have no wins.  This is solved by the
-- COALESCE() statement in COMPLETE_RECORDS since absence here will cause a NULL value there.

CREATE VIEW individual_wins AS
	SELECT player, count(*) AS num_wins FROM individual_outcomes WHERE "w/l/t" = 'w' GROUP BY player;



-- INDIVIDUAL_MATCHES VIEW
-- ***********************
-- Returns a table of each player by ID and the number of matches they have played (NUM_MATCHES).

-- Example:
--  player | num_matches
-- --------+-------------
--       1 |           1
--       2 |           1
--       3 |           1
--       4 |           1

-- Note that there is a player 5 who was had been in a match yet, so is absent from this table.
-- This is solved by the COALESCE() statemet in STANDINGS to replace the NULL value with zero.

CREATE VIEW individual_matches AS
	SELECT player, count(*) AS num_matches FROM individual_outcomes GROUP BY player;



-- COMPLETE_RECORDS VIEW
-- *********************
-- Returns a table of each player by ID, the number of matches they've played as MATCHES, and their number of wins as WINS.
-- This is an unordered version of the total standings table without joining with the player's names.

-- Example:
--  player | matches | wins
-- --------+---------+------
--       1 |       1 |    1
--       2 |       1 |    0
--       3 |       1 |    1
--       4 |       1 |    0

-- Note that player 5 is still absent because this view is derived from MATCHES and player 5 does not appear in any.
-- This view only includes players who have completed a match.

CREATE VIEW complete_records AS
	SELECT individual_matches.player AS player,
		   COALESCE(individual_matches.num_matches, 0) AS matches,
		   COALESCE(individual_wins.num_wins, 0) AS wins
	FROM individual_matches LEFT JOIN individual_wins ON (individual_matches.player = individual_wins.player);

-- STANDINGS VIEW
-- **************
-- JOINS the COMPLETE_RECORDS view with the PLAYERS table to insert the player's full name (NAME) and fills in any
-- resulting empty entries in WINS or MATCHES with zeroes to avoid null entries.  Sorts on WINS in descending order.
-- Ties are split by sorting on opponent match wins (OMW) in descending order.

-- Example:
--  id  |   name    | matches | wins | OMW
-- -----+-----------+---------+------+-----
--  145 | Example 4 |       3 |    3 |   2
--  142 | Example 1 |       3 |    1 |   2
--  144 | Example 3 |       2 |    1 |   1
--  146 | Example 5 |       3 |    1 |   1
--  143 | Example 2 |       3 |    0 |   0

CREATE VIEW standings AS
	SELECT current_tournament_players.id AS id,
		   current_tournament_players.name AS name,
		   COALESCE(complete_records.matches, 0) AS matches,
		   COALESCE(complete_records.wins, 0) AS wins,
		   opponent_match_wins(current_tournament_players.id) AS omw
    FROM current_tournament_players LEFT JOIN complete_records ON (current_tournament_players.id = complete_records.player)
    ORDER BY wins DESC, omw DESC;

-- ----------------------------------------------------------------------------------------------------------------------------
-- Determining the next round pairings:
--
-- These views are used sequentially to build the next round of placements without using Python.  The STANDINGS view is used
-- to generate a placement for each player from 1 to N simply by adding a ROW_NUMBER to it. (This had to be done as a seperate
-- and couldn't be included above because of how the aggregation works.) Then the placements are split into two tables, one
-- of even-ranked players (1st, 3rd, etc) and odd-ranked players (2nd, 4th, etc.). The first player (1st place in the odds,
-- and 2nd place in the evens) in each list is assigned to match 1, the second to match 2 and so forth.  Finally, the two
-- lists are recombined by joining on the NEXT_MATCH value with the odd player being assigned as PLAYER_A and the even
-- player being assigned as PLAYER_B.
-- ----------------------------------------------------------------------------------------------------------------------------

-- ROUND_PLACEMENT VIEW
-- ********************
-- Adds a PLACEMENT column to the STANDINGS view.  The top ranked player will be 1, the second ranked player will be 2,
-- and so forth.  MATCHES and WINS are not included in the new view.

-- Example:
--  placement | id  |   name
-- -----------+-----+-----------
--          1 | 145 | Example 4
--          2 | 142 | Example 1
--          3 | 144 | Example 3
--          4 | 146 | Example 5
--          5 | 143 | Example 2

CREATE VIEW round_placement AS
	SELECT ROW_NUMBER() OVER () AS placement, id, name
	FROM standings;

-- EVEN and ODD PLACEMENT VIEWS
-- ****************************
-- Splits the ROUND_PLACEMENT view into two tables, one consisting of even placements, and one of odd placements.  NEXT_MATCH
-- equates to the ROW_NUMBER() of each entry in the even or odd table.

-- Example:
--  id  |   name    | next_match
-- -----+-----------+------------
--  142 | Example 1 |          1
--  146 | Example 5 |          2

CREATE VIEW even_placements AS
	SELECT id, name, ROW_NUMBER() OVER () AS next_match
	FROM round_placement
	WHERE (placement % 2) = 0
	ORDER BY placement ASC;

-- Example:
--  id  |   name    | next_match
-- -----+-----------+------------
--  145 | Example 4 |          1
--  144 | Example 3 |          2
--  143 | Example 2 |          3

CREATE VIEW odd_placements AS
	SELECT id, name, ROW_NUMBER() OVER () AS next_match
	FROM round_placement
	WHERE (placement % 2) = 1
	ORDER BY placement ASC;

-- NEXT ROUND MATCHUPS VIEW
-- ************************
-- Re-joins the even and odd placement views into a single view of matchups.  The two tables are joined on NEXT_MATCH, which
-- pairs the first odd placement with the first even placement, and so forth.  The odd player is assigned to the PLAYER_A
-- spot and the even player is assigned to the PLAYER_B spot.

-- Example:
--  match | player_a_id | player_a_name | player_b_id | player_b_name
-- -------+-------------+---------------+-------------+---------------
--      1 |         145 | Example 4     |         142 | Example 1
--      2 |         144 | Example 3     |         146 | Example 5

CREATE VIEW next_round_matchups AS
	SELECT odd_placements.next_match AS match,
		   odd_placements.id AS player_a_id,
		   odd_placements.name AS player_a_name,
		   even_placements.id AS player_b_id,
		   even_placements.name AS player_b_name
	FROM odd_placements, even_placements
	WHERE odd_placements.next_match = even_placements.next_match
	ORDER BY match ASC;
