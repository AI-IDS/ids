%% concatenate good columns

Xt=[count,diff_srv_rate,dst_bytes,dst_host_count,dst_host_diff_srv_rate,dst_host_rerror_rate,dst_host_same_src_port_rate,dst_host_same_srv_rate,dst_host_serror_rate,dst_host_srv_count,dst_host_srv_diff_host_rate,dst_host_srv_rerror_rate,dst_host_srv_serror_rate,duration,land,rerror_rate,same_srv_rate,serror_rate,src_bytes,srv_count,srv_diff_host_rate,srv_rerror_rate,srv_serror_rate,urgent,wrong_fragment];

%% booleanize categorical columns

protocol_type_bool=booleanize(protocol_type);
flag_bool=booleanize(flag1);
service_bool=booleanize(service);

%% glue data

Xt=[Xt,protocol_type_bool,flag_bool,service_bool];

%% normalize data

Xt=normc(Xt);

%% booleanize target column

yt=booleanize(tag);

%% all

p=randperm(size(Xt,1));

net_all=netc(Xt(p,:),yt(p,:));

%% split data according to target value

cat=unique(tag);

for i=1:size(cat,1)
   eval(sprintf('%s=Xt(strcmp(tag,cat{i}),:);',cat{i}));
end


%% normal+probing

Xt=[normal,zeros(size(normal,1),1);Probing,ones(size(Probing,1),1)];
Xt=Xt(randperm(size(Xt,1)),:);

net_pb=netc(Xt(:,1:end-1),Xt(:,end));

%% normal+R2L

Xt=[normal,zeros(size(normal,1),1);R2L,ones(size(R2L,1),1)];
Xt=Xt(randperm(size(Xt,1)),:);

net_r2l=netc(Xt(:,1:end-1),Xt(:,end));

%% normal+U2R

Xt=[normal,zeros(size(normal,1),1);U2R,ones(size(U2R,1),1)];
Xt=Xt(randperm(size(Xt,1)),:);

net_u2r=netc(Xt(:,1:end-1),Xt(:,end));

%% normal+DoS

Xt=[normal,zeros(size(normal,1),1);DoS,ones(size(DoS,1),1)];
Xt=Xt(randperm(size(Xt,1)),:);

net_dos=netc(Xt(:,1:end-1),Xt(:,end));


