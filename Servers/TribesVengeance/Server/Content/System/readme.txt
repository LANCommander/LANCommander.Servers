October 7th, 2004

-------------------------------------------------------------------

Tribes: Vengeance - Beta Dedicated Server - version 1.0.0.1

These instructions are laid out in the following order:

System Requirements
Installation
Known Issues
Customizing the Beta Dedicated Server
Using Web Administration Interface
Network Troubleshooting
End-User License Agreement


NOTICE:

* This Tribes: Vengeance - Beta Dedicated Server application is provided "as-is" and is not officially supported by Irrational Games or Sierra Entertainment, Inc.

* Tribes: Vengeance - Beta Dedicated Server application is only recommended for advanced computer users.


-------------------------------------------------------------------

Minimum Specification
 
1. ATI® Radeon™ or equivalent DirectX® 9.0c-compliant 32 MB 3D video card with hardware T&L and pixel shader support
2. Microsoft® Windows® 98/2000/XP operating system
3. 1.0 GHz Intel® Pentium® 4 or AMD® Athlon™ processor or equivalent
4. 256 MB RAM
5. 5 GB of uncompressed hard disk space for game files - An additional 472 Mb hard disk space for Beta Dedicated Server application.
6. DirectX® 9.0c (included with Full game)
7. DirectX®-compatible sound card and speakers or headphones
8. 4X CD-ROM drive
9. Microsoft® compatible mouse and keyboard

 
Recommended Specification: Windows® XP
 
The recommended specification is exactly the same as the minimum specification with the following changes:
 
1. Windows® XP 
2. ATI® Radeon™ 9600 or equivalent DirectX® 9.0c-compliant 128 MB 3D video card with hardware T&L and pixel shader support  
3. 2.5 GHz Intel® Pentium® 4 or AMD® Athlon™ or faster processor
4. 512 MB RAM or more
5. 24X or faster CD-ROM drive
6. Broadband/LAN, DSL or faster Internet connection for online play 


-------------------------------------------------------------------

Installation:

1) Run the self extracting archive for the Beta Dedicated Server. Files will be installed to the program files/vugames/tribes vengeance server/ folder by default.

-------------------------------------------------------------------

Known Issues:


-------------------------------------------------------------------

Customizing the Beta Dedicated Server:

1) In the program files/vugames/tribes vengeance editor/program/bin folder right click on the the Default.ini file.

2) Select "Properties"

3) Uncheck the box marked "Read-Only". Click "Ok".

4) Open Default.ini by double-clicking.

5) Under "[UWeb.WebServer]" find "bEnabled=false" and change to true.

6) Find "ServerName" and change "Another TV Server" to server name of your choice.

7) Close and save Default.ini

8) In the bin folder, open admin TribesAdmin.ini

9) In the second line it will say: "AdminUsers=(AdminName="Admin",Password="Admin"..." 
Change the Admin in the AdminName and Password to your choice. 

10) Close and save TribrsAdmin.ini



Running the Beta Dedicated Server:

1) Run the server executable: TV_Server.exe. The changes that you just made will now be in operation.

2) Open your web browser and enter: "http://localhost:80"

3) When prompted, enter the username and password that you set up as admin login, in steps 8 and 9 above.

You now have access to the Web Administration Interface using your internet browser.  

-------------------------------------------------------------------

Using Web Administration Interface:
  

* Select Current Game on the left and you have options to change the map and game type currently being played. 

* You can log in to WebAdmin from another machine by entering http://<ip>:80 where <ip> is the IP of the server.

Across the top of the WebAdmin screen are three headings: 

Current, Defaults and Admin & Groups.

========================

Current:

Clicking on Current at the top of the screen allows the administrator to change the current game. 

* Clicking on Current Game, allows the Admin to change current map and Game Mode. 

* Player List: allows kicking or banning of players by checking “kick” or “ban” next the player’s name and clicking “kick/ban”. 

* Server Console: allows you to type into the text box. That text is broadcast to players in the Server, allowing you to warn them of any changes being made to the server. 

* Mutators: allows use of mutators (not currently available).

* Restart Level: allows web admin to restart the level.

========================

Defaults:

* Clicking on Defaults at the top brings up Maps and the map rotation list, making changes to this list currently has no effect. 

* Server: allows the administrator to add a password to the game. Note that this will not take effect until the map rotates. 

* IP Bans/Accepts: allows the administrator to ban certain IP’s by clicking “new” and adding the IP. It also displays existing banned IP’s from the server: these can be unbanned by clicking “accept” next to the banned IP, then “update”, or simply clicking “delete” next to the IP. 

* Restart Level: allows web admin to restart the level. 

========================

Admin & Groups:

The final option at the top, Admins and Groups, is not currently implemented.

-------------------------------------------------------------------

NETWORK TROUBLESHOOTING

-------------------------------------------------------------------

If you have an internet connection (e.g. DSL, ADSL or Cable modem) and have installed a “personal firewall” on your computer such as Black Ice, Zone Alarm, Norton Internet Security, etc., you may experience problems joining one of the multiple games found on the Tribes servers. 
To avoid problems with joining and hosting Tribes Vengeance multiplayer game sessions make sure that the ports below are open for UDP/TCP two-way traffic on your firewall. Some personal firewall applications do this setup automatically, depending on how your firewall is configured. Please refer to your firewall instruction manual for information on how to do this.

The following UDP ports need to be opened:
6500
7777
7778
27900



The following TCP ports need to be opened:
7777
7778
28910


If you want to host a game using the game application you need to open up the above ports for outgoing and incoming traffic. If you are behind a NAT/IP firewall you can only host a game by setting up a separate Dedicated Server application and forwarding the required ports to it. 

Please refer to http://www.tribesvengeance.com or http://www.tribalwar.com/ for further information about Dedicated Servers.

-------------------------------------------------------------------

End-User License Agreement

-------------------------------------------------------------------
YOU SHOULD CAREFULLY READ THE FOLLOWING END USER LICENSE AGREEMENT BEFORE INSTALLING THIS SOFTWARE PROGRAM. BY INSTALLING, COPYING, OR OTHERWISE USING THE SOFTWARE PROGRAM, YOU AGREE TO BE BOUND BY THE TERMS OF THIS AGREEMENT. IF YOU DO NOT AGREE TO THE TERMS OF THIS AGREEMENT, DO NOT INSTALL OR OTHERWISE USE THE SOFTWARE PROGRAM

This software program and any files that are provided by Sierra Entertainment, Inc., to you by on-line transmission or otherwise to ‘patch,’ ‘update,’ or modify the software program, as well as any printed materials, on-line or electronic documentation, and any and all copies and derivative works of such software program and materials are the copyrighted work of Sierra, Inc., or its licensors, licensees and suppliers, specifically including Vivendi Universal Games, Inc., and/or its wholly owned subsidiaries (“Sierra”). All use of the Program is governed by the terms of the End User License Agreement which is provided below ("License Agreement"). The Program is solely for use by end users according to the terms of the License Agreement. Any use, reproduction or redistribution of the Program not in accordance with the terms of the License Agreement is expressly prohibited.
END USER LICENSE AGREEMENT

	
1. Limited Use License. Sierra Entertainment, Inc. (“Sierra”) hereby grants, and by installing the Program you thereby accept, a limited, non-exclusive license and right to install and use one (1) copy of the Program for your use on either a home or portable computer. The Program allows you to ‘host’ the Sierra product, “Tribes: Vengeance” on an “internet”  server that you set-up, operate, and maintain as well as on a ‘local access network, or “LAN.” Sierra shall have no financial responsibility for anything related to your hosting the Tribes: Vengeance program. 
	
2. Ownership. All title, ownership rights and intellectual property rights in and to the Program and any and all copies thereof (including but not limited to any titles, computer code, themes, objects, characters, character names, stories, dialog, catch phrases, locations, concepts, artwork, animations, sounds, musical compositions, audio-visual effects, methods of operation, moral rights, any related documentation, and “applets” incorporated into the Program) are owned by Sierra or its licensors. The Program is protected by the copyright laws of the United States, international copyright treaties and conventions, and other laws. All rights are reserved. The Program contains certain licensed materials, and Sierra’s licensors may protect their rights in the event of any violation of this Agreement. The Program may access websites owned, controlled by, or operated by licensed affiliates of Sierra, and receive patches and/or updates to the Program from these websites. All patches, updates or other downloadable material used by, or incorporated into, the Program are the copyrighted property of Sierra, who reserves all rights therein, and shall be governed by the terms and conditions of this Agreement.

	
3. Responsibilities of End User.
	
A. Subject to the Grant of License hereinabove, you may not, in whole or in part, copy, photocopy, reproduce, translate, reverse engineer, derive source code from, modify, disassemble, decompile, create a source code equivalent of, create derivative works based on, or remove any proprietary notices or labels from the Program without the prior consent, in writing, of Sierra.
		
B. The Program is licensed to you as a single product. Its component parts may not be separated for use on more than one computer. 
		
C. You are entitled to use the Program for your own use, but you are not entitled to:

(i) 	sell, grant a security interest in or transfer reproductions of the Program to other parties in any way, nor to rent, lease or license the Program to others without the prior written consent of Sierra;

(ii)	exploit the Program or any of its parts for any commercial purpose, including, but not limited to, use at a cyber café, computer gaming center or any other location-based site;

(iii)	charge players a fee or require other financial consideration to ‘play’ on the internet Server that you create through your use of the Program; 

(iv)	create or maintain connections, whether created by the Program or by other tools and utilities, outside the design of the Program.. Under no circumstances may you connect, or create tools that allow you to connect, to the Program’s private binary interface or interfaces other than those explicitly provided by Sierra for your use.
	
4. Program Transfer. You may permanently transfer all of your rights under this License Agreement, provided the recipient agrees to the terms of this License Agreement and you agree to remove the Program from your home or portable computer.
	
5. Termination. This License Agreement is effective until terminated. You may terminate the License Agreement at any time by destroying the Program. Sierra may, at its discretion, terminate this License Agreement in the event that you fail to comply with the terms and conditions contained herein. In such event, you must immediately destroy the Program. 
	
6. Export Controls. The Program may not be re-exported, downloaded or otherwise exported into (or to a national or resident of) any country to which the U.S. has embargoed goods, or to anyone on the U.S. Treasury Department’s list of Specially Designated Nationals or the U.S. Commerce Department’s Table of Denial Orders. By installing the Program, you are agreeing to the foregoing and you are representing and warranting that you are not located in, under the control of, or a national or resident of any such country or on any such list.

7. Customer Service/Technical Support. Unless otherwise stated in the Program's packaging or in the Program's user manual, nothing herein shall be construed so as to place a duty upon Sierra or its licensees to provide Customer Service or Technical Support for this demonstration version product.

	
8. Limited Warranty. Sierra expressly disclaims any warranty for the Program and Manual(s). The Program and Manual(s) are provided "as is" without warranty of any kind, either express or implied, including, without limitation, the implied warranties of merchantability, fitness for a particular purpose, or non-infringement. Some states do not allow the exclusion or limitation of implied warranties or liability for incidental damages, so the above limitations may not apply to you.

	
9. Limitation of Liability. NEITHER SIERRA NOR ITS PARENT, SUBSIDIARIES OR AFFILIATES OR LICENSEES SHALL BE LIABLE IN ANY WAY FOR LOSS OR DAMAGE OF ANY KIND RESULTING FROM THE USE OF THE PROGRAM, THE EDITOR OR AN AUTHORIZED ON-LINE GAME NETWORK, INCLUDING, BUT NOT LIMITED TO, LOSS OF GOODWILL, WORK STOPPAGE, COMPUTER FAILURE OR MALFUNCTION, OR ANY AND ALL OTHER COMMERCIAL DAMAGES OR LOSSES. ANY WARRANTY AGAINST INFRINGEMENT THAT MAY BE PROVIDED IN SECTION 2-312(3) OF THE UNIFORM COMMERCIAL CODE AND/OR IN ANY OTHER COMPARABLE STATE STATUTE IS EXPRESSLY DISCLAIMED. FURTHER, NEITHER Sierra NOR ITS PARENT, SUBSIDIARIES OR AFFILIATES OR LICENSEES SHALL BE LIABLE IN ANY WAY FOR THE LOSS OR DAMAGE TO PLAYER CHARACTERS, ACCOUNTS, STATISTICS OR USER PROFILE INFORMATION STORED ON AN AUTHORIZED ON-LINE GAME NETWORK. Sierra NOR ITS PARENT, SUBSIDIARIES OR AFFILIATES OR LICENSEES SHALL NOT BE RESPONSIBLE FOR ANY INTERRUPTIONS OF SERVICE, INCLUDING, BUT NOT LIMITED TO, ISP DISRUPTIONS, SOFTWARE OR HARDWARE FAILURES, OR ANY OTHER EVENT WHICH MAY RESULT IN A LOSS OF DATA OR DISRUPTION OF SERVICE. Some states do not allow the exclusion or limitation of incidental or consequential damages, or allow limitations on how long an implied warranty lasts, so the above limitations may not apply.

	
10. Equitable Remedies. You hereby agree that Sierra would be irreparably damaged if the terms of this License Agreement were not specifically enforced, and therefore you agree that Sierra shall be entitled, without bond, other security, or proof of damages, to appropriate equitable remedies with respect to breaches of this License Agreement, in addition to such other remedies as Sierra may otherwise have available to it under applicable laws. In the event any litigation is brought by either party in connection with this License Agreement, the prevailing party in such litigation shall be entitled to recover from the other party all the costs, attorneys’ fees and other expenses incurred by such prevailing party in the litigation.

11. Limitations on License. Nothing in this License Agreement shall preclude you from making or authorizing the making of another copy or adaptation of the Program, provided, however, that 

(1) such new copy or adaptation is created as an essential step in your utilization of the Program in accordance with the terms of this License Agreement and for NO OTHER PURPOSE; or 
(2) such new copy or adaptation is for archival purposes ONLY and all archival copies are destroyed in the event of your Transfer of the Program, the Termination of this Agreement or other circumstances under which your continued use of the Program ceases to be rightful. 
	
12.  Miscellaneous. This License Agreement shall be deemed to have been made and executed in the State of California, and any dispute arising hereunder shall be resolved in accordance with the law of California. You agree that any claim asserted in any legal proceeding by one of the parties against the other shall be commenced and maintained in any state or federal court located in the State of California, County of Los Angeles, having subject matter jurisdiction with respect to the dispute between the parties. This License Agreement may be amended, altered or modified only by an instrument in writing, specifying such amendment, alteration or modification, executed by both parties. In the event that any provision of this License Agreement shall be held by a court or other tribunal of competent jurisdiction to be unenforceable, such provision will be enforced to the maximum extent permissible, and the remaining portions of this License Agreement shall remain in full force and effect. This License Agreement constitutes and contains the entire agreement between the parties with respect to the subject matter hereof and supersedes any prior oral or written agreements.
I hereby acknowledge that I have read and understand the foregoing License Agreement and agree that the action of installing the Program is an acknowledgment of my agreement to be bound by the terms and conditions of the License Agreement contained herein. I also acknowledge and agree that this License Agreement is the complete and exclusive statement of the agreement between Sierra and me and that the License Agreement supersedes any prior or contemporaneous agreement, either oral or written, and any other communications between Sierra and me.


-------------------------------------------------------------------

* NOTICE: Intel and Pentium are Trademarks property of the Intel Corporation.  Athlon and AMD are Trademarks property of the Advanced Micro Devices Corporation.  Windows and Microsoft are Trademarks property of the Microsoft Corporation.  NVIDIA and GeForce are Trademarks property of the NVIDIA Corporation.  ATI and Radeon are Trademarks property of ATI Technologies Incorporated.  Logitech is a Trademark property of the Logitech Corporation.

(C) 2004 Irrational Games. All rights reserved. Tribes Vengeance, Irrational Games and the Irrational Games logo are registered trademarks of Irrational Games in the U.S. and/or other countries.  Published by Vivendi Universal Games International.  Sierra and the Sierra logo are registered trademarks or trademarks of Sierra Entertainment, Inc. in the U.S. and/or other countries. This product contains software technology licensed from GameSpy Industries, Inc. (C) 1999-2004 GameSpy Industries, Inc.  All rights reserved.  All other trademarks are property of their respective owners.

-------------------------------------------------------------------


Thanks to all contributors at www.TribalWar.com, and the testers at VU Games, QA Dept, for help with these instructions.
