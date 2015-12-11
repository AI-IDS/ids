function [ net ] = netc( XT, yT)

% Create a Pattern Recognition Network
net = patternnet(fix(size(XT,2)/2)+1);


% Setup Division of Data for Training, Validation, Testing
net.divideParam.trainRatio = 70/100;
net.divideParam.valRatio = 30/100;
net.divideParam.testRatio = 0/100;

net.trainParam.showWindow=1;

% Train the Network
[net,~] = train(net,XT',yT');

end

