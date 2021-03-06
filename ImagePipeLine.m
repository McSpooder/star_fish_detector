
function ImagePipeLine(name)

    fprintf("\n")
    
    figure(1)
    subplot(4,3,1)
    sgtitle("Image Pipe Line")
    
    %loading in the image
    img = imread(name);
    img = img(:,:,3);
    subplot(4,3,1)
    imshow(img)
    title("Initial Image")
    
    %%% Image Processing %%%
    out = ImageProcessing(img);
    
    %%% Image Analysis %%%      
    ImageAnalysis(out);
    
    x = (5);
    fprintf("There are %6.2f starfish. \n",x);
    
end


function out = ImageProcessing(img)

    disp("Enhancing Image...")
    out = Enhancement(img);
    subplot(4,3,2)
    imshow(out)
    title('Enhanced Image')
    
    disp("Getting Binary Mask...")
    out = GetBinaryMask(out);
    subplot(4,3,3)
    imshow(out)
    title('Binary Mask')
    
end


function out = ImageAnalysis(mask)

    disp("Applying Morphology...")
    out = ApplyMorphology(mask,2);
    subplot(4,3,4)
    imshow(out)
    title("Post Morphology")
    
    disp("Applying Watershed")
    labels = WatershedSegment(out, 1);
    figure(1)
    col_seg = label2rgb(labels,'jet',[.5 .5 .5]);
    subplot(4,3,5)
    imshow(col_seg)
    title("Watershed Segmentation")
    
    disp("Getting Shape Descriptors")
    regp = FilterRegionProps(labels);
    
    subplot(4,3,[7,8,9,10])
    DisplayCentroids(regp, out);
    DisplayBounding(regp)
    
end


function out = Enhancement(img)

    disp("--Applying Blur...")
    out = MeanBlur(img, "valid");
    out = UnsharpMask(out);
    out = UnsharpMask(out);
    disp("--Applying equalization...")

    
end


function out = MeanBlur(img, method)

    filter = ones(3)/9;
    
    [~, ~, Chans] = size(img);
    if Chans == 3
        R=img(:, :, 1);
        G=img(:, :, 2);
        B=img(:, :, 3);

        out_r = uint8(conv2(double(R), filter, method));
        out_g = uint8(conv2(double(G), filter, method));
        out_b = uint8(conv2(double(B), filter, method));

        out = cat(3, out_r, out_g, out_b);       
    end
    
    if Chans == 1
        out = uint8(conv2(double(img), filter, method));
    end
    
end


function out = UnsharpMask(img)

    blured = MeanBlur(img, "same");
    edges = img - blured;
    out = img + edges;

end


function out = GetBinaryMask(img)

    disp("--Extracting the Initial Mask...")
    [~, ~, Chans] = size(img);
    if Chans == 3
       img = rgb2gray(img);
    end

    bmask = ~imbinarize(img);

    %imfill
    disp("--Filling in the Holes...")
    CONN = [ 0 1 0; 1 1 1; 0 1 0 ];
    out = imfill(bmask, CONN, 'holes');
    
    disp("--Removing isolated Points")
    out = RemoveIsolated(out);
    
end


function out = RemoveIsolated(bmask)
    %hitmiss
    interval = [-1,0,-1; 0,1,0; -1,0,-1];
    morphed = bwhitmiss(bmask, interval);
    out = bmask - morphed;
end


function out = ApplyMorphology(bmask, loops)

    se = [0,1,0; 1,1,1; 0,1,0];
    out = bmask;
    
    for n = 1:loops
        disp("--Erroding the Image")
        out = imerode(out, se);
        disp("--Dilating the Image")
        out = imdilate(out, se);
    end
    
    disp("--Erroding the Image")
    out = imerode(out, se);
    
    out = RemoveIsolated(out);
    
    for n = 1:loops
        disp("--Erroding the Image")
        out = imerode(out, se);

        disp("--Dilating the Image")
        out = imdilate(out, se);
    end
    
    disp("--Erroding the Image")
    out = imerode(out, se);
    out = RemoveIsolated(out);
    
    
end

function out = WatershedSegment(mask, display)

    disp("Applying Distance Transform...")
    D = bwdist(~mask);
    D_comp = -D;
    
    disp("Applying minimum extend")
    ext_mask = imextendedmin(D_comp,1);%was 2
    D2 = imimposemin(D_comp,ext_mask);
    
    disp("Applying Watershed Transform")
    L = watershed(D2);
    seg_mask = mask;
    seg_mask(L == 0) = 0;

    L(~mask) = 0;
    out = L;

    if display == 1
        figure (2)
        subplot(2,2,1)
        imshow(D,[])
        title('Distance Transform of Binary Image')
        subplot(2,2,2)
        imshow(D_comp,[])
        title('Complement of Distance Transform')
        subplot(2,2,3)
        imshowpair(mask,ext_mask,'blend')
        title("Minimum extended overlayed")
        subplot(2,2,4)
        imshow(seg_mask)
        title('Original Mask Segmented')        
    end

end


function regp = FilterRegionProps(labels)

    regp = regionprops(labels, "centroid", "ConvexArea", "BoundingBox", "Solidity");
    convexArea = cat(1, regp.ConvexArea);
    solidity = cat(1, regp.Solidity);

    deleted = 0;
    for n = 1:length(convexArea)
        if convexArea(n) < 1500
            %delete the record from s
            regp(n-deleted) = [];
            deleted = deleted + 1;
        elseif solidity(n) > 0.6
            regp(n-deleted) = [];
            deleted = deleted + 1;
        end
    end

end


function  DisplayCentroids(regprops, mask)
    
    centroids = cat(1, regprops.Centroid); 
    imshow(mask)
    hold on
    plot(centroids(:,1), centroids(:,2),'b*')
    hold off
    
end


function DisplayBounding(regprops)

    bb = cat(1, regprops.BoundingBox);
    for i = 1:size(bb)
        rectangle("Position",[bb(i,1) bb(i,2) bb(i,3) bb(i,4)],'EdgeColor','green');
    end
    
end

