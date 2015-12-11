%%

X=[0 0 0
    0 1 0
    1 0 0
    1 1 0
    ];

y=[0 1 1 0]';

%%

net=netCreate(X,y);

net(X')

%%

fun = @(XT,yT,Xt,yt)netEval(XT,yT,Xt,yt);
opts = statset('display','iter','useparallel',true);
[inmodel,history]=sequentialfs(fun,X,y,'cv',3,'options',opts);


%%

fun = @(XT,yT,Xt,yt)netEval(XT,yT,Xt,yt);
opts = statset('display','iter','useparallel',true);
[inmodel,history]=sequentialfs(fun,normc(bfSSH_train),bfSSH_target,'cv',10,'options',opts);

%%
netCreate(normc(bfSSH_train(:,inmodel)),bfSSH_target);

%%

% Test the Network
y = net(x);
e = gsubtract(t,y);
tind = vec2ind(t);
yind = vec2ind(y);
percentErrors = sum(tind ~= yind)/numel(tind);
performance = perform(net,t,y)


% View the Network
view(net)

% Plots
% Uncomment these lines to enable various plots.
%figure, plotperform(tr)
%figure, plottrainstate(tr)
%figure, plotconfusion(t,y)
%figure, plotroc(t,y)
%figure, ploterrhist(e)
