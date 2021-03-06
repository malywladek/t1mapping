%%%% vfa t1-mappping with b1 correction
%dependencies: spm, coregister, cell_rdir, t1_calc, fillgaps...



%%%%%%%%%%%
%%%%INPUTS
%%%%%%%%%%%%

clear all; close all;

inputs=cell_rdir('**/gre_4*/gre*1.nii');
gre18=cell(size(inputs));
rfmag=cell(size(inputs));
rfmap=cell(size(inputs));
for i=1:size(inputs,1)
    subj=fileparts(fileparts(inputs{i}));
    gre18(i)=cell_rdir([subj,'/gre_18*/gre*1.nii']);
    rfmap(i)=cell_rdir([subj,'/rf_map*/rfmaps*2.nii']);
    rfmag(i)=cell_rdir([subj,'/rf_map*/rfmaps*1.nii']);
end
inputs(:,2)=gre18';
inputs(:,3)=rfmag';
inputs(:,4)=rfmap';



%%%%%%%%%%%%%
%%%MAIN LOOP
%%%%%%%%%%%%%

for i=1:size(inputs,1)
    curimgs=inputs(i,:);
    imgs=spm_vol(char(strcat(curimgs,',1')));
    
    %%%%%%%%%%%%%
    %%%PREPROC
    %%%%%%%%%%%%%
    
    %reorder rf map images
    imgs(3)=rf_slicer(imgs(3));
    imgs(4)=rf_slicer(imgs(4));

    %coregister estimate and reslice 2nd FLASH
    imgs(2)=coregister(imgs(1).fname,imgs(2).fname,'');
    
    %repair outliers in rfmap
    rf_raw=spm_read_vols(imgs(3));
    dval=sort(rf_raw(:));
    thresh=0.01*mean(dval(end-10:end));
    rf_mask=rf_raw>thresh;
    imgs(4)=repair_img(imgs(4).fname,rf_mask);
    
    
    %coregister est&reslice RF-Map
    imgs(4)=coregister(imgs(1).fname,imgs(3).fname,imgs(4).fname,1); %ref src oth interp
    % smooth rf map
    imgs(4)=smooth(imgs(4).fname,12,1);

    %%%%%%%%%%%%%
    %%%MAPPING
    %%%%%%%%%%%%%
    
    %read preprocessed files
    img1=spm_read_vols(imgs(1));
    img2=spm_read_vols(imgs(2));
    b1_img=spm_read_vols(imgs(4));

%     mask=(mat2gray(img1)>(graythresh(img1)*0.1));
%     se = strel('disk',10);
%     closeBW = imclose(mask,se);
%     img1(~mask)=NaN;
%     img2(~mask)=NaN;

    %Small angle aproximation
    [t1map,pdmap]=t1_calc(img1(:,:,:),img2(:,:,:));
    
    %%%%%%%%%%%%%
    %%%POSTPROC
    %%%%%%%%%%%%%

    %%%% b1 correction
    b1_img(b1_img==0)=NaN;
    b1_deg=zeros(size(b1_img));
    b1_deg(b1_img>2048)=(b1_img(b1_img>2048)-2048)*180/2048;
    b1_r=b1_deg/90;
    t1map_c=t1map./(b1_r.^2);
    pdmap_c=pdmap./b1_r;

    %%%% spoiling correction (?) -> Preibisch 2009
    A=275*b1_r.^2-359*b1_r+142; %[ms]
    B=-0.33*b1_r.^2+0.25*b1_r+0.92;
    t1map_c2=A+B.*t1map_c;

    subplot(1,3,1); imshow(squeeze(pdmap_c(:,200,:)),[3000 6000]); title('Proton density');
    subplot(1,3,2); imshow(squeeze(t1map_c2(:,200,:)),[300 3000]); title('T1 map');
    subplot(1,3,3); imshow(squeeze(b1_deg(:,200,:)),[]); title('B1 map');
    %subplot(1,3,3); imshowpair(img1(:,:,80),mask(:,:,80)); title('mask');

    %%%%%%%%%%%%%
    %%%WRITING
    %%%%%%%%%%%%%
    
    VO = imgs(1); % copy info from gre_1
    [pth, bnm, ext] = spm_fileparts(VO.fname);
    VO.fname = fullfile(pth, ['pdmap' ext]);
    spm_write_vol(VO,pdmap_c);
    VO.fname = fullfile(pth, ['b1map' ext]);
    spm_write_vol(VO,b1_deg);
    VO.fname = fullfile(pth, ['t1map' ext]);
    spm_write_vol(VO,t1map_c2);
    if(exist('mask','var'))
        VO.fname = fullfile(pth, ['mask' ext]);
        spm_write_vol(VO,mask);
    end

end
