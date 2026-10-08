import Foundation

/// The built-in, original Practice Card (SPEC §9.6). It is never persisted.
public enum PracticeCard {
  public static let text = """
! Practice Card
!year 2026
# Year
FF 2026/x 2222/y 6666/y ; 25 ; X ; Year Kongs
2222/x 000 222/y 6666/z ; 25 ; X ; Soap Year
FF NEWS 2026/x 2026/y ; 50 ; C ; Compass Year
2026/x 2026/y 2026/z DD/x ; 75 ; C ; Triple Year
# 2468
222/x 4444/x 666/x 8888/x ; 25 ; X ; Even Climb
FF 2222/x 44/y 66/y 8888/x ; 25 ; X ; Even Bookends
22/x 444/x 66/y 888/y DDDD/z ; 30 ; X ; Even Dragons
FFFF 2468/x 222/y 888/z ; 25 ; X ; Even Spread
FF 22/x 44/x 66/x 88/x 2468/y ; 50 ; C ; Even Pairs
# Like Numbers
FF 1111/x 11/y 1111/z DD/x ; 25 ; X ; Like Sandwich ; shift
1111/x 1111/y 111/z FFF ; 25 ; X ; Like Trio ; shift
FF 11/x 11/y 11/z DD/x DD/y DD/z ; 50 ; C ; Like Pairs ; shift
# Addition
FF 3333/x + 4444/y = 7777/z ; 25 ; X ; Three Plus Four
FF 1111/x + 5555/x = 6666/x ; 30 ; X ; One Plus Five
22/x + 55/x = 77/x 22/y + 55/y = 77/y FF ; 50 ; C ; Double Sum
# Quints
FFFF 11111/x 22222/y ; 45 ; X ; Quint Steps ; shift
NNNNN EEEE 11111/x | SSSSS WWWW 11111/x ; 40 ; X ; Wind Quints ; shift
11111/x DDDD/x 11111/y ; 45 ; X ; Like Quints ; shift
# Consecutive Run
11/x 222/x 3333/x 444/x 55/x ; 25 ; X ; Five Step Run ; shift
FFF 1111/x 2222/y 333/z ; 25 ; X ; Three Suit Run ; shift
111/x 2222/x 333/y 4444/y ; 25 ; X ; Two Suit Run ; shift
FF 1/x 22/x 333/x 4444/x 55/x ; 30 ; X ; Staircase ; shift
112233/x 445566/y FF ; 50 ; C ; Pair Ladder ; shift
# 13579
11/x 333/x 5555/x 777/x 99/x ; 25 ; X ; Odd Climb
FFFF 1111/x 9999/y 55/z ; 25 ; X ; Odd Ends
111/x 33/x 555/y 77/y 9999/z ; 30 ; X ; Odd Spread
13579/x 13579/y FFFF ; 40 ; C ; Odd Singles
11/x 33/x 55/x 77/x 99/x 11/y 99/y ; 50 ; C ; Odd Pairs
# Winds & Dragons
NNNN EEE WWW SSSS ; 25 ; X ; Four Winds
FF RRR GGG 000 NNN | FF RRR GGG 000 EEE | FF RRR GGG 000 WWW | FF RRR GGG 000 SSS ; 30 ; X ; Dragons And A Wind
NNN SSS DDDD/x DDDD/y ; 25 ; X ; North South Dragons
NEWS RR GG 00 FFFF ; 35 ; C ; Compass Dragons
# 369
333/x 666/x 9999/x DDDD/x ; 25 ; X ; Threes In One
FF 3333/x 6666/y 9999/z ; 25 ; X ; Threes Across
FF 33/x 66/x 99/x 33/y 66/y 99/y ; 50 ; C ; Threes In Pairs
# Singles & Pairs
NN EE WW SS 11/x 11/y 11/z ; 50 ; C ; Winds And Likes ; shift
FF 11/x 22/x 33/x 44/x 55/x 66/x ; 50 ; C ; Pair Run ; shift
"""

  public static let card: Card = {
    let parsed = Notation.parseCardFile(text)
    return Notation.makeCard(
      from: parsed, id: "practice-v1", builtIn: true, fallbackName: "Practice Card",
      createdAt: Date(timeIntervalSince1970: 1_790_000_000))
  }()
}
