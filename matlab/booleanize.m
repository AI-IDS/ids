function [ X ] = booleanize( x )
    header=unique(x);

    X=zeros(size(x,1),size(header,1));

    for i=1:size(header,1)
        X(:,i)=strcmp(x,header(i));
    end
end

