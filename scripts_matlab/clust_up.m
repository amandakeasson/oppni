function vol2 = clust_up( vol, minclust, varargin )
%
% =========================================================================
% CLUST_UP: Cluster-size thresholding on 3D volume
% =========================================================================
%
% Syntax:
%           vol2 = clust_up( vol, minclust )
%
% Input:
%           vol: 3D volume, clusterized based on binary thresholding
%                (x==0 vs x~=0)
%      minclust: minimum cluster-size threshold. Must be 3 or more
%
% Output:
%          vol2: cluster thresholded image
%

if(ischar(vol))
    volnii = vol;
    V=load_untouch_nii(volnii);
    vol = double(V.img);
    fromnii = true;
else
    fromnii = false;
end

if(nargin>2) 
    outfile = varargin{1}; 
    toout   = true;
    if(nargin==4) oformat = varargin{2}; 
    else          oformat = 'standard';
    end
    if( ~strcmpi(oformat,'standard') && ~strcmpi(oformat,'simple'))
        error('unrecognized output text format');
    end
else
    toout   = false;
end

D=size(vol); if(length(D)<3) D(3)=1; end
bino = double( vol~=0 );

C1   = knn( bino );
C1   = C1.*bino;
C2   = knn(C1);
C2   = C2.*bino;
% at least 2 neighbours
bino_th   = double(C2>=2);

if( minclust <3 )
    
    error('minimum cluster size threshold of 3!');

elseif( minclust==3 )
    
    vol2 = vol.*bino_th;

    disp('No cluster-size reporting for minclust=3. Assuming it is just cleanup!');
else
    
    % now fit to minclust
    vox_idx      = find( bino_th > 0 );
    clust_set{1} = [vox_idx(1)];
    Nclust=1;

    for(i=2:length(vox_idx))
       %[i length(vox_idx)],    

       kn=zeros(Nclust,1);
       for(j=1:Nclust)
           [ic jc kc] =ind2sub(D, clust_set{j});
           [ix jx kx] =ind2sub(D, vox_idx(i));
           kn(j,1) = max( (abs(ic-ix)<=1) .* (abs(jc-jx)<=1) .* (abs(kc-kx)<=1) );
       end
       assn = find( kn );

       if( isempty(assn) )
           Nclust=Nclust+1;
           clust_set{Nclust} = vox_idx(i);
       elseif( length(assn)==1 )
           clust_set{assn} = [clust_set{assn}; vox_idx(i)]; 
       else
           % merging
           Nclust = Nclust - length(assn)+1;
           new_clust=[];
           for(k=1:length(assn)) new_clust = [new_clust; clust_set{assn(k)}]; end
           clust_set(assn)=[];
           clust_set{Nclust} = [new_clust; vox_idx(i)];
       end
    end

    for(i=1:Nclust) 
        ClustSize(i,1) = length(clust_set{i});
    end
    rowix = sortrows([(1:Nclust)' ClustSize],-2);
    clust_set=clust_set(rowix(:,1));

    clust_map=zeros(size(vol));
    Nclust2=0;
    for(i=1:Nclust)
        %ClustSize(i,1) = length( clust_set{i} );
        if( length(clust_set{i}) >= minclust )
            Nclust2 = Nclust2+1; 
            clust_map(clust_set{i})=Nclust2;
        end
    end
    %figure,imagesc( clust_map );
    
    if(toout)
        % initialize output file
        fin = fopen(outfile,'wt');
        fprintf(fin,'\nCluster-size report, minimum cluster size =%s',num2str(minclust));
        if(fromnii) fprintf(fin,'\ninput files =%s\n\n',volnii);
        else        fprintf(fin,'\nused 3d input matrix\n\n');
        end
    end
    
    strout = ['total number of clusters: ',num2str(Nclust2)];
    disp(strout);
    if(toout) fprintf(fin,[strout,'\n\n']); end

    for(n=1:Nclust2)
        vtemp  = clust_map(clust_map(:) == n);
        bintmp = double(clust_map==n);
        voltmp = vol.*double(clust_map==n);
        [x y z] = ind2sub( D, find(abs(voltmp)==max(abs(voltmp(:)))));
        
        val{1} = numel(vtemp); %size
        val{2} = [x,y,z]; %peak coordinates
        %%%
        d1=sum(sum(abs(voltmp),2),3); xc = sum(d1(:).*(1:size(bintmp,1))')./sum(d1(:));
        d1=sum(sum(abs(voltmp),1),3); yc = sum(d1(:).*(1:size(bintmp,2))')./sum(d1(:));
        d1=sum(sum(abs(voltmp),1),2); zc = sum(d1(:).*(1:size(bintmp,3))')./sum(d1(:));    
        val{3}=round([xc yc zc]);
        %%%
        val{4} = voltmp(x(1),y(1),z(1)); %peak value
        strout = ['Clust #',num2str(n),', size=',num2str(val{1}),...
                                  ', coords(com) =[',num2str(val{3}(1)),',',num2str(val{3}(2)),',',num2str(val{3}(3)),...                                  
                                 '], peak=',sprintf('%0.2f',val{4})];
        disp(strout);
        if(toout)
            if( strcmpi(oformat,'standard') )
                fprintf(fin,[strout,'\n']); 
            else
                strout = sprintf('%u,%u,%u,%u,%u,%0.2f',n,val{1},val{3}(1),val{3}(2),val{3}(3),val{4});
                fprintf(fin,[strout,'\n']); 
            end
        end
    end
    
    vol2 = vol.*double(clust_map>0);
    
    if(toout) fclose(fin); end
end

%%
function count = knn( X )

D=size(X); if(length(D)<3) D(3)=1; end
count = 0;
count = count + cat( 1, zeros([1,D(2),D(3)]), X(1:end-1,:,:) );
count = count + cat( 1, X(2:end,:,:), zeros([1,D(2),D(3)]) );
count = count + cat( 2, zeros([D(1),1,D(3)]), X(:,1:end-1,:) );
count = count + cat( 2, X(:,2:end,:), zeros([D(1),1,D(3)]) );
if(D(3)>1)
count = count + cat( 3, zeros([D(1),D(2),1]), X(:,:,1:end-1) );
count = count + cat( 3, X(:,:,2:end), zeros([D(1),D(2),1]) );
end