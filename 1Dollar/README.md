# 1Dollar Module

## Intro
1Dollar is a Dapp where users can get a big bonus with a small investment. Users can buy tickets for unwrapped Boxes which will be open with a winner when all the tickets are sold. The winner has the right to take the assets(coins or tokens) in the box.

## Main function:

### 1.Create Box

The creators who are configured by the 1Dollar module can create boxes by depositing coins or tokens into the module and setting up parameters such as the number of tickets、price or single ticket、selling time and etc. The assets (box and payment of tickets) will be locked in the module until the winner claims the reward or the box is out of date.

### 2.Buy tickets

Users can buy tickets for boxes and the tickets are stored in the user's account resource as vouchers for claiming rewards or refunding. And the tickets can be transferred if the Box is alive.

### 3.Claim rewards

The holder of the ticket with the lucky code can claim the asset of the Box.
Ps: 1Dollar will use the signature to register the coin resource of reward type for the winner if she/he hasn't registered it.

### 4.refund

If the tickets are not sold out within the selling time, the ticket holders of this Box can have a full refund by interacting with our website or 1Dollar module directly.

### 5.generate lucky code

The lucky code will be generated when the last ticket is sold and the winner is the holder of the ticket with the lucky code.
The algorithm of generate lucky code is following:

The seed of random number is consist of :

1 . address of the last transaction's sender
2.a counter in the module
3.current block height
4.current time stamp
5.hash of the script being executed
6.current sequence number of the sender

These data will be serialized to bytes and joined together, lucky code is generated by calculating the hash of these bytes mod the sum of tickets.

