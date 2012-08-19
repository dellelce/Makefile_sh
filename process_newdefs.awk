# 1745 131008 Adding "IncludeAllCnt", states map and comments to old features

# States map
#
#
# State		Description
#--------------+-----------------------------------------------
# 0            | Default/Home
# 1            | ..........
# 2            | ..........
#

     BEGIN {
	     State = 0;
	     CurRule = "";
	     AllRules = "";
	     RuleCnt = 0;
             IncludeAllCnt = 0;
           } 

# Ignore comments...

      $1 ~ /^#/ { print $0; next; }

      State==0 && /=/ && $0 ~ /^RULE_/        { 
				                split ($0, vec, "=");
               			                printf "export %s=%s\n", vec[1], vec[2];
        			                next;
	   			              }

      State==0 && /=/ 		              { 
				                split ($0, vec, "=");
						eqpos=index($0a,"=")+1;
               			                printf "export %s=%s\n", toupper(vec[1]), substr($0, eqpos, length($0));
        			                next;
	   			              }

#Added 0330 091108 removed: ???? 091108
      State==0 && /+=/ 		              { 
				                split ($0, vec, "+=");
               			                printf "export %s=\"%s %s\"\n", 
							  toupper(vec[1]),
							  toupper(vec[1]), vec[2];
        			                next;
	   			              }

      State==0 && $1 ~ /^include/  {
				     print "include ", $2;
				     next;
		                   }
#match "force_include_all"
# only two args supported

      State==0 && $1 ~ /^force_include_all/ {
                                              IncludeAllCnt = IncludeAllCnt + 1;
                                              IncludeAllArray[IncludeAllCnt] = $2; 
                                            }

#cfile
# 1709 061108

#      State==0 && $1 ~ /^cfile/ {
                                              #work in progress
                                              #x
#                                }

#match "rule" keyword

      State==0 && $1 ~ /^rule/  {
                                  print "";
                                  CurRule = $2;
                                  AllRules = sprintf ("%s %s", AllRules, CurRule);

                                  if ($3 == "{")
                                   {
                                     State = 2;  
                                   }
                                  else
                                   {
                                     State = 1;
                                   }

                                  RuleCnt = RuleCnt + 1;
                                  next;
		                }

      State==1 && $1 == "{"   {
                                State = 2; next;
                              }

      State==1                {
                                print "error=",$0; next;
                              }

      State==2 && $1 == "}"   {
                                State = 0; CurRule = ""; next;
                              }

      State==2&&$1~/CFILE/    {
                                split ($0, vec, "=");
                                gsub(/ /, "", vec[1]);
                                sub(/ /, "", vec[2]);
                                gsub(/\"/, "", vec[2]);
                                printf ("export CFILES=\"${CFILES} %s\"\n", vec[2]);
			        next;
                              }

      State==2                {
                                split ($0, vec, "=");
                                gsub(/ /, "", vec[1]);
                                sub(/ /, "", vec[2]);
                                printf ("export RULE_%s_%s=%s\n", toupper(vec[1]), CurRule, vec[2]);
                              }

       END                    {
				print "";
				if (RuleCnt > 0)
				 {
				   print "export RULES=\"", AllRules, "\"";
				 }
			      } 


## EOF ''
