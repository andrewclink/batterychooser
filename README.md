# batterychooser
Compares specs and pricing of batteries from a certain website to make choosing 
18650 cells easier.

There are lots of considerations when building a battery pack:
1. Cost
2. Capacity
3. Maximum discharge rate
4. Wear suceptibility (Lifespan)
4. Voltage
5. Size (and thus assembly time and cost)
6. Weight

A battery pack that contains 100 cells might be acceptable if you could get the 
cells for $1 each. But if you could match that capacity with a pack containing 
36 cells, for slightly higher cost and 10x the lifetime, it'd be a good deal.

This quick and dirty script compares all 18650 cells listed on a reputable vendor's
website (caching the pages first- I checked in my cache so that's what you'll get 
unless you delete it). Modify variables toward the end of the script as you see fit.

Add OptionParser and submit a pull request!

Perhaps someday I'll make this into a website.

# Installation

- fork
- bundle install
- ./extract.rb

# Example output
    Searching 80 cells
    Samsung 25R 18650                  : 6s6p        120 A |       15.0 Ah |        9.0 Ah after 250 | $137 | 36 x $3.80
    LG MF1 18650                       : 6s9p         90 A |      19.35 Ah |       11.6 Ah after 250 | $143 | 54 x $2.65
    LG HE2 18650                       : 6s6p        120 A |       15.0 Ah |        9.0 Ah after 250 | $144 | 36 x $4.00
    Samsung 20Q 18650                  : 6s8p        120 A |       16.0 Ah |        9.6 Ah after 250 | $144 | 48 x $3.00
    LG HE4 18650                       : 6s6p        120 A |       15.0 Ah |        9.0 Ah after 250 | $144 | 36 x $4.00
    Samsung 22P 18650                  : 6s8p         80 A |       17.6 Ah |       10.6 Ah after 250 | $148 | 50 x $2.95
    Sanyo UR18650NSX                   : 6s6p        120 A |       15.6 Ah |        9.4 Ah after 250 | $149 | 36 x $4.15
    LG HD1 18650                       : 6s8p        120 A |       16.0 Ah |        9.6 Ah after 250 | $150 | 50 x $3.00

