from __future__ import division
import nflgame
from itertools import groupby

#import nflgame.update_players
#nflgame.update_players.run()

#change this to be the filepath and name of file you want output. don't delete the quotes
file = 'C:\Users\Ben\Dropbox\SEA\stats\data\gamelogs\success.txt'

#what week of the season do you want? 0 for all weeks
#if you enter 0 here it takes longer because it's every play in the season
gameweek = 0



if gameweek>0:
    games = nflgame.games(year=2016, week=gameweek)
else: games = nflgame.games(year=2016)

plays = nflgame.combine_plays(games)

data=[]
for play in plays:
    theplay = str(play)
    for player in play.players:
        if player.receiving_tar==1:
            if theplay.find('spike') == -1:

                #print play
                #print player
                #player, id, target, reception, pass success, rec yards, rec td, rush att, rush yards, rush success, rush td, fumble, suc rec yd, suc rush yd, ints
                togo = int(theplay.split('and')[1].split(')')[0])
                if play.down == 1:
                    success = int(player.receiving_yds / togo >= .5)
                elif play.down == 2:
                    success = int(player.receiving_yds / togo >= .7)
                else:
                    success = play.passing_first_down

                suc_yd = success * player.receiving_yds
                if theplay.find('INTERCEPTED')>0:
                    ints = 1
                else:
                    ints = 0

                try:
                    x = (str(player.player.full_name), str(player.player.profile_id), 1, player.receiving_rec, success, player.receiving_yds, player.receiving_tds, 0, 0, 0, 0, player.fumbles_tot, suc_yd, 0, ints)
                    data.append(x)
                except:
                    print "Note: player not in datbase (skipping):", str(player)

        elif player.rushing_att==1:
            #print play
            if theplay.find('kneels') == -1:
                #player, id, target, reception, pass success, rec yards, rec td, rush att, rush yards, rush success, rush td, fumble, suc rec yd, suc rush yd, ints
                togo = int(theplay.split('and')[1].split(')')[0])
                if play.down == 1:
                    success = int(player.rushing_yds / togo >= .5)
                elif play.down == 2:
                    success = int(player.rushing_yds / togo >= .7)
                else:
                    success = play.rushing_first_down

                suc_yd = success * player.rushing_yds

                try:
                    x = (str(player.player.full_name), str(player.player.profile_id),  0, 0, 0, 0, 0, 1, player.rushing_yds, success, player.rushing_tds, player.fumbles_tot, 0, suc_yd, 0)
                    data.append(x)
                except:
                    print "Note: player not in datbase (skipping):", str(player)
                try:
                    if str(player.player.full_name) == "Reggie Bush":
                        print play
                        print player.rushing_yds, success, suc_yd
                except:
                    continue

data = sorted(data, key=lambda data: data[1])

export = []

for key, group in groupby(data, lambda x: x[1]):
    toadd = [0, key, 0, 0, 0, 0 ,0 ,0 ,0 ,0 ,0, 0, 0, 0, 0]
    for thing in group:
        # 0,         1,    2,    3,          4,          5,         6,           7,      8,            9,         10,      11,      12,         13,         14
        # player,    id, target, reception, pass success, rec yards, rec td, rush att, rush yards, rush success, rush td, fumble, suc rec yd, suc rush yd, ints
        for i in range(2,len(x)):
            toadd[i] = toadd[i] + thing[i]
        toadd[0] = thing[0]


    #print toadd
    export.append(toadd)

export = sorted(export, key=lambda export: export[12], reverse=True)

f = open(file, 'w')

f.write("player, ID, target, reception, pass success, rec yards, rec td, rush att, rush yards, rush success, rush td, fumble, suc rec yd, suc rush yd, targeted ints\n")

for line in export:
    f.write(", ".join(map(str, line)))
    f.write("\n")
f.close()

    # http://burntsushi.net/stuff/nfldb/nfldb.pdf
