function [ e ] = nete( XT,yT,Xt,yt )
net=netCreate(XT,yT);

e=perform(net,net(Xt')',yt)
end

