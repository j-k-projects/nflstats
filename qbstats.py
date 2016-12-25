"""
NOTE: THERE ARE 3 CHOICES YOU CAN MAKE BELOW
DO NOT MAKE CHANGES TO ANY OTHER LINES UNLESS YOU KNOW WHAT YOU'RE DOING
    1. THE FILE WHERE OUTPUT IS SAVED (line 18 below)
    2. THE WEEK YOU WANT DATA FROM (line 23)
    3. THE SEASON YOU WANT DATA FROM (line 26)

last edit 12/25/2016 Ben B @guga31bb
"""

#don't change this block
from __future__ import division
import nflgame
from itertools import groupby


#1. change this to be the filepath and name of file you want output. don't delete the quotes
file = 'C:\Users\Ben\Dropbox\SEA\stats\data\gamelogs\TAY.txt'

#2. what week of the season do you want?
# either pick the specific week to get stats from that week (eg gameweek = 16)
# or enter 0 to get totals for the entire season (gameweek = 0)
gameweek = 16

#3. which season do you want? pick a number greater than or equal to 2009
getyear = 2016

#that's all, run the program and the output will be saved to a .csv text file


if gameweek>0:
    games = nflgame.games(year=getyear, week=gameweek)
else: games = nflgame.games(year=getyear)

plays = nflgame.combine_plays(games)

data=[]
for play in plays:
    theplay = str(play)
    for player in play.players:
        if player.passing_att==1:
            if theplay.find('spike') == -1:
                #player, cmp, att, yds, td, int, (6)
                # sk, sky, p1d, psuc, spk, air, yac, (7)
                # rush, ryds, rtd, fumb, r1d, rsuc, kneel, kneelyd (8)
                togo = int(theplay.split('and')[1].split(')')[0])
                if play.down == 1:
                    success = int(player.passing_yds / togo >= .5)
                elif play.down == 2:
                    success = int(player.passing_yds / togo >= .7)
                else:
                    success = play.passing_first_down
                if player.passing_cmp==1:
                    yac = player.passing_yds - player.passing_cmp_air_yds
                else:
                    yac = 0
                x = (str(player), player.passing_cmp, 1, player.passing_yds, player.passing_tds, player.passing_int, \
                    0, 0, play.passing_first_down, success, 0, player.passing_cmp_air_yds, yac, \
                    0, 0, 0, 0, 0, 0, 0, 0)
                data.append(x)
            else:
                x = (str(player), 0, 0, 0, 0, 0, \
                     0, 0, 0, 0, 1, 0, 0, \
                     0, 0, 0, 0, 0, 0, 0, 0)
                data.append(x)
        elif player.rushing_att==1:
            #print play
            if theplay.find('kneels') == -1:
                # player, cmp, att, yds, td, int, (6)
                # sk, sky, p1d, psuc, spk, air, yac, (7)
                # rush, ryds, rtd, fumb, r1d, rsuc, kneel, kneelyd (8)

                togo = int(theplay.split('and')[1].split(')')[0])
                if play.down == 1:
                    success = int(player.rushing_yds / togo >= .5)
                elif play.down == 2:
                    success = int(player.rushing_yds / togo >= .7)
                else:
                    success = play.rushing_first_down
                x = (str(player), 0, 0, 0, 0, 0, \
                     0, 0, 0, 0, 0, 0, 0, \
                     1, player.rushing_yds, player.rushing_tds, player.fumbles_tot, play.rushing_first_down, success, 0, 0)
                data.append(x)
            else:
                #print theplay
                x = (str(player), 0, 0, 0, 0, 0, \
                     0, 0, 0, 0, 0, 0, 0, \
                     0, 0, 0, 0, 0, 0, 1, player.rushing_yds)
                data.append(x)
        elif player.passing_sk==1:
            # player, cmp, att, yds, td, int, (6)
            # sk, sky, p1d, psuc, spk, air, yac, (7)
            # rush, ryds, rtd, fumb, r1d, rsuc, kneel, kneelyd (8)
            x = (str(player), 0, 0, 0, 0, 0, \
                 1, player.passing_sk_yds, 0, 0, 0, 0, 0, \
                 0, 0, 0, player.fumbles_tot, 0, 0, 0, 0)

            data.append(x)

data = sorted(data, key=lambda data: data[0])

export = []

for key, group in groupby(data, lambda x: x[0]):
    toadd = [key, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    #         0               5              10             15             20
    for thing in group:
        # player, cmp, att, yds, td, int,
        #   0      1    2    3   4    5
        # sk, sky, p1d, psuc, spk, air, yac,
        #  6    7    8   9     10    11  12
        # rush, ryds, rtd, fumb, r1d, rsuc, kneel, kneelyd
        # 13     14    15   16   17    18    19     20

        for i in range(1,len(x)):
            toadd[i] = toadd[i] + thing[i]

    #only keeping people with at least 2 pass attempts (this is mainly to filter out running backs)
    if toadd[2] > 1:
        #print toadd
        export.append(toadd)

export = sorted(export, key=lambda export: export[0], reverse=True)


f = open(file, 'w')
f.write("player, cmp, att, passing yds, passing TD, int, sk, sky, passing 1D, passing successes, spike, air yd, yac, rush, rush yds, rush TD, fumb, rush 1D, rushing successes, kneel, kneelyd\n")

for line in export:
    f.write(", ".join(map(str, line)))
    f.write("\n")
f.close()

    # http://burntsushi.net/stuff/nfldb/nfldb.pdf
